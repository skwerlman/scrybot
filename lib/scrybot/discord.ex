defmodule Scrybot.Discord do
  @moduledoc false
  use Supervisor
  require Logger
  alias Scrybot.Discord.Command

  def start_link(_) do
    Command.init()
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  defp children do
    schedulers = System.schedulers_online()
    target_workers = Application.get_env(:scrybot, :workers, :auto)

    workers =
      case target_workers do
        :auto -> schedulers
        _ -> target_workers
      end

    for i <- 1..workers do
      Supervisor.child_spec(
        Scrybot.Discord.Worker,
        id: {Scrybot.Discord.Worker, i}
      )
    end
  end

  def init(:ok) do
    opts = [strategy: :one_for_one, name: Scrybot.Discord.Supervisor]
    Supervisor.init(children(), opts)
  end
end
