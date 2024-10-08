defmodule Scrybot.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :scrybot,
      version: "0.16.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Scrybot.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:lib_judge, "~> 0.4"},
      {:nostrum, "~> 0.10"},
      {:con_cache, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:ex_rated, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"},
      {:floki, "~> 0.34"},
      {:tesla, "~> 1.4"},
      {:mint, "~> 1.4"},
      {:castore, "~> 1.0"},
      {:toml, "~> 0.7"},
      {:telemetry, "~> 1.1", override: true},
      {:flex_logger, "~> 0.2"},
      {:logger_file_backend, "~> 0.0"},
      {:ex_doc, ">= 0.0.0", runtime: false, only: :dev},
      {:dialyxir, "~> 1.3", runtime: false, only: [:dev, :test]},
      {:gradient, github: "esl/gradient", runtime: false, only: [:dev, :test]},
      {:credo, "~> 1.7", runtime: false, only: [:dev, :test]}
    ]
  end

  defp dialyzer do
    plt =
      case Mix.env() do
        # this fixes a failure when dialyxir is run in a test env
        :test ->
          [:ex_unit]

        _ ->
          []
      end

    [
      plt_add_apps: plt,
      flags: [
        :error_handling,
        # Enable this for debugging only
        # :specdiffs,
        :underspecs,
        :unknown,
        :unmatched_returns
      ]
    ]
  end
end
