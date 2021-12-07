defmodule Scrybot.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :scrybot,
      version: "0.14.7",
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
      # {:nostrum, path: "/mnt/code/nostrum"},
      {:nostrum, github: "kraigie/nostrum"},
      {:con_cache, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:ex_rated, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"},
      {:floki, "~> 0.30"},
      {:tesla, "~> 1.4"},
      {:toml, "~> 0.6"},
      {:telemetry, "~> 1.0", override: true},
      # {:prom_ex, "~> 1.3"},
      {:gun, "~> 2.0", hex: :remedy_gun, override: true},
      {:cowlib, "~> 2.11.1", hex: :remedy_cowlib, override: true},
      {:flex_logger, "~> 0.2"},
      {:logger_file_backend, "~> 0.0"},
      {:ex_doc, ">= 0.0.0", runtime: false, only: :dev},
      {:dialyxir, "~> 1.1", runtime: false, only: [:dev, :test]},
      {:credo, "~> 1.5", runtime: false, only: [:dev, :test]}
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
        :unmatched_returns,
        :error_handling,
        :race_conditions,
        :no_opaque,
        :underspecs
      ]
    ]
  end
end
