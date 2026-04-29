defmodule JSONLogFormatter do
  @moduledoc """
  A JSON one-liner log formatter.

  To enable it, configure the console backend (or any other `Logger`
  backend you are using) to format the logs using this module:

      config :logger, :default_formatter,
        format: {#{inspect(__MODULE__)}, :format}

  The formatter expects the timestamps to be in UTC. The `Logger`
  should be configured accordingly:

      config :logger, :default_formatter, utc_log: true

  It's also recommended to disable colors:

      config :logger, :default_formatter, colors: [enabled: false]

  See `format/4` for more information.
  """

  @reserved_keys [:level, :timestamp, :message]
  @new_line_patterns ["\r\n", "\n"]

  @doc """
  Formats a log message as a JSON one-liner.

  If the message contains multiple lines, each line will be
  returned as a separated log message.

  Timestamps are in UTC with a precision of milliseconds, and
  they are expressed following the ISO 8601:2004 format.
  Check the module documentation for more information.

  The keys `:level`, `:timestamp`, and `:message` are reserved and
  they cannot be included in the given `metadata`; otherwise an error
  message will be included as an additional log message in the final
  output.

  Additional error messages may be included in the final output if
  the given `metadata` is not a keyword list, or if it contains
  duplicated keys or keys with multi-line strings.

  If for any reason the message cannot be formatted as a JSON
  one-liner, an error message will be returned as final output.
  """
  @spec format(Logger.level(), IO.chardata(), Logger.Formatter.date_time_ms(), keyword) ::
          IO.chardata()
  def format(level, message, timestamp, metadata) do
    timestamp = format_timestamp(timestamp)
    {metadata, error_messages} = format_metadata(metadata)
    messages = message |> IO.chardata_to_string() |> to_lines()

    [
      Enum.map(error_messages, &encode_log_entry(:error, &1, timestamp, metadata)),
      Enum.map(messages, &encode_log_entry(level, &1, timestamp, metadata))
    ]
  end

  defp encode_log_entry(level, message, timestamp, metadata) do
    log_entry =
      metadata
      |> Map.put(:level, level)
      |> Map.put(:message, message)
      |> Map.put(:timestamp, timestamp)

    [Jason.encode!(log_entry), "\n"]
  end

  defp format_timestamp({date, {hour, minute, second, millisecond}}) do
    {date, {hour, minute, second}}
    |> NaiveDateTime.from_erl!({millisecond * 1000, 3})
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp format_metadata(metadata) do
    if Keyword.keyword?(metadata) do
      Enum.reduce(metadata, {%{}, []}, fn {key, value}, {formatted_metadata, error_messages} ->
        cond do
          key == :file and is_list(value) ->
            formatted_metadata = Map.put(formatted_metadata, key, List.to_string(value))
            {formatted_metadata, error_messages}

          key in @reserved_keys ->
            error_message = "Logger metadata contains reserved key #{inspect(key)}"
            {formatted_metadata, [error_message | error_messages]}

          Map.has_key?(formatted_metadata, key) ->
            error_message = "Logger metadata contains duplicated key #{inspect(key)}"
            formatted_metadata = Map.put(formatted_metadata, key, value)
            {formatted_metadata, [error_message | error_messages]}

          match?({:error, _}, Jason.encode(value)) ->
            inspected_value = inspect(value, printable_limit: :infinity, limit: :infinity)
            formatted_metadata = Map.put(formatted_metadata, key, inspected_value)
            {formatted_metadata, error_messages}

          true ->
            formatted_metadata = Map.put(formatted_metadata, key, value)
            {Map.put(formatted_metadata, key, value), error_messages}
        end
      end)
    else
      {%{}, ["Logger metadata is not a keyword list"]}
    end
  end

  defp to_lines(string), do: String.split(string, @new_line_patterns)
end
