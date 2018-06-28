defmodule Scrybot.Cache do
  @moduledoc false
  @cacheid Scrybot.Cache.ScryfallCache
  use Supervisor

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec init(term()) ::
          {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
          | :ignore
  def init(_) do
    children = [
      {ConCache,
       [
         name: @cacheid,
         # 30 minutes
         ttl_check_interval: 30 * 60 * 1000,
         # 2 days
         global_ttl: 48 * 60 * 60 * 1000,
         ets_options: [read_concurrency: true, name: :scryfall_cache_ets]
       ]}
    ]

    opts = [strategy: :one_for_one, name: Scrybot.Cache.Supervisor]
    Supervisor.init(children, opts)
  end
end

defmodule Scrybot.Cache.Middleware do
  @moduledoc false
  @behaviour Tesla.Middleware
  @cacheid Scrybot.Cache.ScryfallCache
  require Logger

  def call(env, next, _options) do
    case ConCache.get(@cacheid, {env.url, env.query}) do
      nil ->
        Logger.info("hitting the real api: #{inspect({env.url, env.query})}")
        {:ok, result} = Tesla.run(env, next)

        case result do
          %{status: status} when status in 200..299 ->
            ConCache.put(@cacheid, {env.url, env.query}, result.body)

          %{status: status} ->
            Logger.warn("not caching: status #{inspect(status)}")
        end

        {:ok, result}

      cached ->
        Logger.debug("url was cached")
        {:ok, %{env | body: cached}}
    end
  end
end
