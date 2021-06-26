defmodule Scrybot.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :scrybot,
      version: "0.14.1",
      elixir: "~> 1.9",
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
      {:lib_judge, github: "skwerlman/lib_judge"},
      # {:nostrum, path: "/mnt/code/nostrum"},
      {:nostrum, github: "kraigie/nostrum"},
      {:con_cache, "~> 0.14"},
      {:jason, "~> 1.2"},
      {:ex_rated, "~> 1.3"},
      {:elixir_uuid, "~> 1.2"},
      {:floki, "~> 0.30"},
      {:tesla, "~> 1.4"},
      {:toml, "~> 0.6"},
      {:httpoison, "~> 1.7", override: true},
      {:gun, ">= 2.0.0-rc.2", override: true},
      {:flex_logger, "~> 0.2"},
      {:logger_file_backend, "~> 0.0"},
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
