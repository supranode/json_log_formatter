defmodule JSONLogFormatter.MixProject do
  use Mix.Project

  @version "1.0.0"
  @scm_url "https://github.com/supranode/json_log_formatter"

  def project do
    [
      app: :json_log_formatter,
      description: "A JSON one-liner log formatter",
      version: @version,
      elixir: "~> 1.18",
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def cli do
    [
      preferred_envs: [docs: :docs]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.40.3", only: :docs}
    ]
  end

  defp package do
    [
      maintainers: ["Fernando Tapia Rico"],
      licenses: ["MIT"],
      links: %{"GitHub" => @scm_url},
      files: ~w(mix.exs README.md lib)
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "JSONLogFormatter",
      source_url: @scm_url
    ]
  end
end
