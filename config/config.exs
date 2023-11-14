import Config

config :logger, :default_formatter, format: {JSONLogFormatter, :format}
