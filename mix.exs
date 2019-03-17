defmodule Scrybot.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :scrybot,
      version: "0.5.1",
      elixir: "~> 1.7",
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
      {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
      {:con_cache, "~> 0.13"},
      {:jason, "~> 1.1"},
      {:ex_rated, "~> 1.3"},
      {:elixir_uuid, "~> 1.2"},
      {:tesla, "~> 1.2"},
      {:httpoison, "~> 1.4", override: true},
      {:nimble_parsec, "~> 0.5"},
      {:flex_logger, "~> 0.2"},
      {:logger_file_backend, "~> 0.0"},
      {:distillery, "~> 2.0", runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", runtime: false, only: [:dev, :test]},
      {:credo, "~> 1.0", runtime: false, only: [:dev, :test]}
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
