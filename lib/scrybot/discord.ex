defmodule Scrybot.Discord do
  @moduledoc false
  use Supervisor
  alias Scrybot.Discord.Command

  @spec start_link(any()) :: {:error, any()} | {:ok, pid()}
  def start_link(_) do
    Command.init()
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  defp children do
    [
      Scrybot.Discord.FailureDispatcher,
      Scrybot.Discord.Worker
    ]
  end

  @spec init(:ok) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
  def init(:ok) do
    opts = [strategy: :one_for_one]
    Supervisor.init(children(), opts)
  end
end
