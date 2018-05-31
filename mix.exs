defmodule Scrybot.MixProject do
  use Mix.Project

  def project do
    [
      app: :scrybot,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:jason, "~> 1.0"},
      {:named_args, "~> 0.1"},
      {:tesla, ">= 1.0.0-beta.1"}
    ]
  end
end
