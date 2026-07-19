defmodule JSONLogFormatter do
  @moduledoc """
  A JSON one-line log formatter.

  To enable it, configure the console backend (or any other `Logger`
  backend in use) to use this module for formatting:

      config :logger, :default_formatter,
        format: {#{inspect(__MODULE__)}, :format}

  The formatter expects timestamps in UTC, so `Logger`
  should be configured accordingly:

      config :logger, :default_formatter, utc_log: true

  It's also recommended to disable colors:

      config :logger, :default_formatter, colors: [enabled: false]

  Metadata values that cannot be encoded to JSON are rendered via
  `inspect/2`. The options passed to `inspect/2` can be configured with:

      config :json_log_formatter, inspect: [limit: 50, printable_limit: 4096]

  Defaults to Elixir's `inspect/2` defaults. Set the bounds higher to
  retain more detail at the cost of larger log entries, or to `:infinity`
  to disable them entirely. See `Inspect.Opts` for the list of available
  options.

  Multi-line messages are emitted as a single JSON entry by default,
  with newlines escaped in the `message` field. To split each line
  into a separate log entry instead, configure:

      config :json_log_formatter, split_multiline_messages: true

  See `format/4` for more information.
  """

  import Application, only: [compile_env: 3]

  @reserved_keys [:level, :timestamp, :message]
  @inspect_opts compile_env(:json_log_formatter, :inspect, [])
  @split_multiline_messages compile_env(:json_log_formatter, :split_multiline_messages, false)

  @doc """
  Formats a log message as a JSON one-liner.

  Multi-line messages are emitted as a single JSON entry with
  newlines escaped in the `message` field. To split each line into
  a separate log entry instead, see the module documentation.

  Timestamps are in UTC with millisecond precision and
  are formatted according to the ISO 8601:2004 standard.
  See the module documentation for more information.

  The keys `:level`, `:timestamp`, and `:message` are reserved and
  must not be included in the given `metadata`. If they are present,
  an error message is emitted as an additional log message.

  Additional error log messages may also be emitted if the
  given `metadata` is not a keyword list or contains duplicate keys.

  If for any reason the message cannot be formatted as a JSON
  one-liner, an additional error log message is emitted.
  """
  @spec format(Logger.level(), IO.chardata(), Logger.Formatter.date_time_ms(), keyword) ::
          IO.chardata()
  def format(level, message, timestamp, metadata) do
    timestamp = format_timestamp(timestamp)
    {metadata, error_messages} = format_metadata(metadata)
    messages = message |> IO.chardata_to_string() |> to_messages()

    [
      Enum.map(error_messages, &encode_log_entry(:error, &1, timestamp, metadata)),
      Enum.map(messages, &encode_log_entry(level, &1, timestamp, metadata))
    ]
  rescue
    exception ->
      error_message = "Failed to encode log entry as JSON: #{Exception.message(exception)}"
      timestamp = DateTime.to_iso8601(DateTime.utc_now(:millisecond))
      [Jason.encode!(%{level: :error, message: error_message, timestamp: timestamp}), "\n"]
  end

  defp encode_log_entry(level, message, timestamp, metadata) do
    log_entry =
      metadata
      |> Map.put(:level, level)
      |> Map.put(:message, message)
      |> Map.put(:timestamp, timestamp)

    [Jason.encode!(log_entry), "\n"]
  end

  if @split_multiline_messages do
    defp to_messages(message), do: String.split(message, ["\r\n", "\n"])
  else
    defp to_messages(message), do: [message]
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
          key in @reserved_keys ->
            error_message = "Logger metadata contains reserved key #{inspect(key)}"
            {formatted_metadata, [error_message | error_messages]}

          Map.has_key?(formatted_metadata, key) ->
            error_message = "Logger metadata contains duplicated key #{inspect(key)}"
            formatted_metadata = Map.put(formatted_metadata, key, format_metadata_value(value))
            {formatted_metadata, [error_message | error_messages]}

          true ->
            formatted_metadata = Map.put(formatted_metadata, key, format_metadata_value(value))
            {formatted_metadata, error_messages}
        end
      end)
    else
      {%{}, ["Logger metadata is not a keyword list"]}
    end
  end

  defp format_metadata_value(value) do
    cond do
      is_list(value) and value != [] and List.ascii_printable?(value) -> List.to_string(value)
      json_encodable?(value) -> value
      true -> inspect(value, @inspect_opts)
    end
  end

  defp json_encodable?(value) when is_number(value) or is_atom(value), do: true
  defp json_encodable?(value) when is_binary(value), do: String.valid?(value)

  defp json_encodable?(value) when is_list(value),
    do: not List.improper?(value) and Enum.all?(value, &json_encodable?/1)

  defp json_encodable?(value), do: match?({:ok, _}, Jason.encode(value))
end
