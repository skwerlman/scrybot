defmodule Scrybot.Scryfall.Cache do
  @moduledoc false
  use Supervisor

  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl Supervisor
  @spec init(:ok) :: {:ok, {:supervisor.sup_flags(), [:supervisor.child_spec()]}}
  def init(:ok) do
    children = [
      {ConCache,
       [
         name: id(),
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

  @spec id() :: Scrybot.Scryfall.CacheWorker
  def id, do: Scrybot.Scryfall.CacheWorker
end

defmodule Scrybot.Scryfall.Cache.Middleware do
  @moduledoc false
  @behaviour Tesla.Middleware
  require Logger
  use Scrybot.LogMacros
  alias Scrybot.Scryfall.Cache

  @impl Tesla.Middleware
  @spec call(Tesla.Env.t(), any, any) :: Tesla.Env.result()
  def call(env = %Tesla.Env{query: query, url: url}, next, _options) do
    case ConCache.get(Cache.id(), {url, query}) do
      nil ->
        info("hitting the real api: #{inspect({url, query})}")
        {status, result} = Tesla.run(env, next)

        if status == :ok do
          case result do
            %{status: status} when status in 200..299 ->
              ConCache.put(Cache.id(), {url, query}, result.body)

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

  def call(%Tesla.Env{}, _next, _options) do
    {:error, :missing_query_or_url}
  end
end
