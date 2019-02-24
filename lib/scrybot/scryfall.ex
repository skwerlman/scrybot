defmodule Scrybot.Scryfall do
  @moduledoc false
  use Supervisor
  require Logger
  alias Scrybot.Scryfall.Api

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      Scrybot.Scryfall.Cache
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
