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

    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, metadata) == [
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "expires_on" => "1987-05-06",
               "message" => "Hello world!",
               "file" => "test.exs",
               "line" => 15,
               "mfa" => "{JSONLogFormatterTest, :test, 2}",
               "pid" => inspect(self())
             }
           ]
  end

  test "format/4 supports multi-line messages" do
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

    assert format(:info, message, {{2019, 10, 11}, {13, 24, 56, 0}}, metadata) == [
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "message" => "This is a",
               "file" => "test.exs",
               "function" => "test/2",
               "line" => 15,
               "module" => "Elixir.Test"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "message" => "multi-line",
               "file" => "test.exs",
               "function" => "test/2",
               "line" => 15,
               "module" => "Elixir.Test"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "message" => "message",
               "file" => "test.exs",
               "function" => "test/2",
               "line" => 15,
               "module" => "Elixir.Test"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "message" => "",
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

  test "format/4 formats timestamps using the ISO 8601:2004 format" do
    assert [%{"timestamp" => "2019-10-11T13:24:56Z"}] =
             format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 3000}})
  end

  test "format/4 formats metadata" do
    metadata = [
      env: "test",
      params: %{ids: [1, 2], avg: 3.4, primary: true},
      multiline: """
      This is a
      multiline string
      """
    ]

    assert format(:notice, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, metadata) == [
             %{
               "level" => "notice",
               "timestamp" => "2019-10-11T13:24:56Z",
               "env" => "test",
               "params" => %{"ids" => [1, 2], "avg" => 3.4, "primary" => true},
               "message" => "Hello world!",
               "multiline" => "This is a\nmultiline string\n"
             }
           ]
  end

  test "format/4 raises if the message is not chardata" do
    assert_raise FunctionClauseError, ~r[chardata_to_string/1], fn ->
      format(:info, :no_chardata)
    end
  end

  defmodule User do
    defstruct [:name]
  end

  test "format/4 transforms non JSON serializable values into strings using inspect/2" do
    metadata = [
      result: {:ok, "This cannot be encoded to JSON"},
      env: "test",
      user: %User{name: "Fernando"},
      pid: self()
    ]

    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, metadata) == [
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "env" => "test",
               "result" => ~s({:ok, "This cannot be encoded to JSON"}),
               "user" => ~s(%JSONLogFormatterTest.User{name: "Fernando"}),
               "pid" => inspect(self()),
               "message" => "Hello world!"
             }
           ]
  end

  test "format/4 logs an error message if the metadata contains reserved keys" do
    metadata = [test: "This is a valid key", message: "This is a reserved key"]

    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, metadata) == [
             %{
               "level" => "error",
               "timestamp" => "2019-10-11T13:24:56Z",
               "test" => "This is a valid key",
               "message" => "Logger metadata contains reserved key :message"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "test" => "This is a valid key",
               "message" => "Hello world!"
             }
           ]
  end

  test "format/4 logs an error message if the metadata contains duplicated keys" do
    metadata = [name: "Fer", name: "Fernando", env: "test"]

    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, metadata) == [
             %{
               "level" => "error",
               "timestamp" => "2019-10-11T13:24:56Z",
               "env" => "test",
               "name" => "Fernando",
               "message" => "Logger metadata contains duplicated key :name"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "env" => "test",
               "name" => "Fernando",
               "message" => "Hello world!"
             }
           ]
  end

  test "format/4 logs an error message if the metadata is not a keyword list" do
    assert format(:info, "Hello world!", {{2019, 10, 11}, {13, 24, 56, 0}}, :invalid) == [
             %{
               "level" => "error",
               "timestamp" => "2019-10-11T13:24:56Z",
               "message" => "Logger metadata is not a keyword list"
             },
             %{
               "level" => "info",
               "timestamp" => "2019-10-11T13:24:56Z",
               "message" => "Hello world!"
             }
           ]
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
