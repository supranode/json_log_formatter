defmodule JSONLogFormatterTest do
  use ExUnit.Case, async: true

  test "format/4 formats log messages as JSON one-liners" do
    metadata = [
      expires_on: ~D[1987-05-06],
      mfa: {__MODULE__, :test, 2},
      file: ~c"test.exs",
      line: 15,
      pid: self()
    ]

    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 123}}, metadata) == [
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56.123Z",
               "message" => "Hello world!",
               "expires_on" => "1987-05-06",
               "mfa" => "{JSONLogFormatterTest, :test, 2}",
               "file" => "test.exs",
               "line" => 15,
               "pid" => inspect(self())
             }
           ]
  end

  test "format/4 preserves multi-line messages as a single entry" do
    metadata = [
      module: Test,
      function: "test/2",
      file: "test.exs",
      line: 15
    ]

    message = """
    This is a
    multi-line
    message
    """

    assert format(:info, message, {{2019, 10, 11}, {13, 24, 56, 882}}, metadata) == [
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56.882Z",
               "message" => "This is a\nmulti-line\nmessage\n",
               "file" => "test.exs",
               "function" => "test/2",
               "line" => 15,
               "module" => "Elixir.Test"
             }
           ]
  end

  test "format/4 supports messages that are chardata" do
    assert [%{"message" => "Hello æß π"}] = format(:debug, ["Hello ", [0x00E6, 0x00DF, " "], ?π])
  end

  test "format/4 formats metadata" do
    metadata = [
      charlist: ~c"Fernando",
      string: "test",
      encodable_map: %{list: [1, 2], boolean: true},
      non_encodable_map: %{list: [1, 2], tuple: {:ok, true}},
      encodable_list: [1, "two", 3.0, [true, false], %{key: nil}],
      non_encodable_list: [1, {:ok, 2}],
      empty_list: [],
      improper_list: [:improper, :list | true],
      multiline_string: """
      This is a
      multiline string
      """,
      tuple: {:ok, [:list, %{map: true}]},
      pid: self()
    ]

    assert format(:notice, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, metadata) == [
             %{
               "level" => "notice",
               "timestamp" => "2019-10-11T13:24:56.000Z",
               "message" => "Hello world!",
               "charlist" => "Fernando",
               "string" => "test",
               "encodable_map" => %{"list" => [1, 2], "boolean" => true},
               "non_encodable_map" => "%{list: [1, 2], tuple: {:ok, true}}",
               "encodable_list" => [1, "two", 3.0, [true, false], %{"key" => nil}],
               "non_encodable_list" => "[1, {:ok, 2}]",
               "empty_list" => [],
               "improper_list" => "[:improper, :list | true]",
               "multiline_string" => "This is a\nmultiline string\n",
               "tuple" => "{:ok, [:list, %{map: true}]}",
               "pid" => inspect(self())
             }
           ]
  end

  test "format/4 uses :inspect options for non JSON encodable values" do
    # The :inspect printable_limit is set at compile time in config/config.exs.
    metadata = [data: {:printable_limit, "This is a fairly long string"}]

    assert [%{"data" => "{:printable_limit, \"This is a fairly lon\" <> ...}"}] =
             format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, metadata)
  end

  test "format/4 logs an error message if the metadata contains reserved keys" do
    metadata = [test: "This is a valid key", message: ~c"This is a reserved key"]

    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 572}}, metadata) == [
             %{
               "level" => "error",
               "timestamp" => "2019-10-11T13:24:56.572Z",
               "test" => "This is a valid key",
               "message" => "Logger metadata contains reserved key :message"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56.572Z",
               "test" => "This is a valid key",
               "message" => "Hello world!"
             }
           ]
  end

  test "format/4 logs an error message if the metadata contains duplicated keys" do
    metadata = [name: "Fer", name: "Fernando", env: "test", pid: "0.0.1", pid: self()]

    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 741}}, metadata) == [
             %{
               "level" => "error",
               "timestamp" => "2019-10-11T13:24:56.741Z",
               "env" => "test",
               "name" => "Fernando",
               "message" => "Logger metadata contains duplicated key :pid",
               "pid" => inspect(self())
             },
             %{
               "level" => "error",
               "timestamp" => "2019-10-11T13:24:56.741Z",
               "env" => "test",
               "name" => "Fernando",
               "message" => "Logger metadata contains duplicated key :name",
               "pid" => inspect(self())
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56.741Z",
               "env" => "test",
               "name" => "Fernando",
               "message" => "Hello world!",
               "pid" => inspect(self())
             }
           ]
  end

  test "format/4 logs an error message if the metadata is not a keyword list" do
    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 7}}, :invalid) == [
             %{
               "level" => "error",
               "timestamp" => "2019-10-11T13:24:56.007Z",
               "message" => "Logger metadata is not a keyword list"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56.007Z",
               "message" => "Hello world!"
             }
           ]
  end

  test "format/4 logs an error message if JSON encoding fails" do
    # Unlike metadata values, the log level isn't sanitized and is
    # passed directly to Jason.encode!/1, triggering the encoding failure.
    non_json_encodable_log_level = self()

    assert [
             %{
               "level" => "error",
               "timestamp" => _timestamp,
               "message" => "Failed to encode log entry as JSON: protocol Jason.Encoder" <> _
             }
           ] = format(non_json_encodable_log_level, "Hi!", {{2019, 10, 11}, {13, 24, 56, 0}}, [])
  end

  test "format/4 logs an error message if the message is not chardata" do
    assert [
             %{
               "level" => "error",
               "timestamp" => _timestamp,
               "message" =>
                 "Failed to encode log entry as JSON: no function clause matching in " <>
                   "IO.chardata_to_string/1"
             }
           ] = format(:info, :no_chardata)
  end

  defp format(level, message, timestamp \\ {{2019, 10, 11}, {13, 24, 56, 0}}, metadata \\ []) do
    chardata = JSONLogFormatter.format(level, message, timestamp, metadata)
    log = IO.chardata_to_string(chardata)

    assert String.ends_with?(log, "\n")

    log
    |> String.replace_suffix("\n", "")
    |> String.split("\n")
    |> Enum.map(&Jason.decode!/1)
  end
end
