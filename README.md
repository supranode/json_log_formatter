# JSONLogFormatter

A JSON one-line log formatter for [Elixir's Logger](https://hexdocs.pm/logger).

## Installation

Add `:json_log_formatter` to the project's dependencies in the `mix.exs` file:

```elixir
def deps do
  [
    {:json_log_formatter, "~> 1.0.0"}
  ]
end
```

And then fetch your project's dependencies: `mix deps.get`

## Usage

Configure the console backend (or any other `Logger` backend in use)
to use this module for formatting:

```elixir
config :logger, :default_formatter, format: {JSONLogFormatter, :format}
```

The formatter expects timestamps in UTC, so `Logger` should be
configured accordingly:

```elixir
config :logger, :default_formatter, utc_log: true
```

It's also recommended to disable colors:

```elixir
config :logger, :default_formatter, colors: [enabled: false]
```

Metadata values that cannot be encoded to JSON are rendered via
`inspect/2`. The options passed to `inspect/2` can be configured with:

```elixir
config :json_log_formatter, inspect: [limit: 50, printable_limit: 4096]
```

Multi-line messages are emitted as a single JSON entry by default,
with newlines escaped in the `message` field. To split each line
into a separate log entry instead, configure:

```elixir
config :json_log_formatter, split_multiline_messages: true
```

See the `JSONLogFormatter` module documentation for more details.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/supranode/json_log_formatter.

## Copyright and License

`JSONLogFormatter` source code is licensed under the [MIT License](LICENSE).
