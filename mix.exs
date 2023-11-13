defmodule JsonLogFormatter.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/supranode/json_log_formatter"

  def project do
    [
      app: :json_log_formatter,
      description: "A JSON one-liner log formatter",
      version: @version,
      elixir: "~> 1.15",
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      organization: "supranode",
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
