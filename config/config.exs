import Config

config :logger, :default_formatter, format: {JSONLogFormatter, :format}
config :json_log_formatter, inspect: [printable_limit: 20]
