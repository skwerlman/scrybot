defmodule Scrybot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias Scrybot.Scryfall.Api
  use Application

  def start(_type, _args) do
    # Initialize the scryfall ratelimiter
    Api.setup()

    # List all child processes to be supervised
    children = [
      Scrybot.Cache,
      Scrybot.Discord
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Scrybot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
