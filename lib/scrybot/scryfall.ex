defmodule Scrybot.Scryfall do
  @moduledoc false
  use Supervisor

  @spec start_link(any()) :: {:error, any()} | {:ok, pid()} | :ignore
  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec init(:ok) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
  def init(:ok) do
    children = [
      Scrybot.Scryfall.Cache
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end
