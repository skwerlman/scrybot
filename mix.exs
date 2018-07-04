defmodule Scrybot.MixProject do
  use Mix.Project

  def project do
    [
      app: :scrybot,
      version: "0.1.2",
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
      {:jason, "~> 1.1"},
      {:named_args, "~> 0.1"},
      {:opq, "~> 3.0"},
      {:elixir_uuid, "~> 1.2"},
      {:tesla, "~> 1.0"},
      {:flex_logger, "~> 0.2"},
      {:logger_file_backend, "~> 0.0"},
      {:distillery, "~> 1.5", runtime: false}
    ]
  end
end
