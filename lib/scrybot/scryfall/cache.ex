defmodule Scrybot.Scryfall.Cache do
  @moduledoc false
  @cacheid Scrybot.Scryfall.CacheWorker
  use Supervisor

  @spec start_link(term()) :: Supervisor.on_start()
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

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end
end

defmodule Scrybot.Scryfall.Cache.Middleware do
  @moduledoc false
  @behaviour Tesla.Middleware
  @cacheid Scrybot.Scryfall.CacheWorker
  require Logger
  import Scrybot.LogMacros

  def call(env, next, _options) do
    case ConCache.get(@cacheid, {env.url, env.query}) do
      nil ->
        info("hitting the real api: #{inspect({env.url, env.query})}")
        {status, result} = Tesla.run(env, next)

        if status == :ok do
          case result do
            %{status: status} when status in 200..299 ->
              ConCache.put(@cacheid, {env.url, env.query}, result.body)

            %{status: status} ->
              warn("not caching: status #{inspect(status)}")
          end

          {:ok, result}
        else
          {:error, result}
        end

      cached ->
        debug("url was cached")
        {:ok, %{env | body: cached}}
    end
  end
end
