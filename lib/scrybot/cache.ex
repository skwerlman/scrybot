defmodule Scrybot.Cache do
  @moduledoc false
  @cacheid Scrybot.Cache.ScryfallCache
  use Supervisor

  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
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
        Logger.warn("hitting the real api: #{inspect({env.url, env.query})}")
        {:ok, result} = Tesla.run(env, next)
        ConCache.put(@cacheid, {env.url, env.query}, result.body)
        result

      cached ->
        Logger.warn("url was cached")
        %{env | body: cached}
    end
  end
end
