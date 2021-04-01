defmodule Scrybot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  use Application

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    # Load MTG rules into memory before starting
    rules =
      "20210224"
      |> LibJudge.get!()
      |> LibJudge.tokenize()

    Application.put_env(:scrybot, :rules, rules)

    # List all child processes to be supervised
    children = [
      Scrybot.Scryfall,
      Scrybot.Discord
      # Scrybot.Rules
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Scrybot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
