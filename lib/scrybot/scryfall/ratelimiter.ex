defmodule Scrybot.Scryfall.Ratelimiter.Middleware do
  @moduledoc false
  @behaviour Tesla.Middleware
  require Logger
  import Scrybot.LogMacros

  defp block_while_limited(bucket_info = {name, timeframe, requests}) do
    {status, _remaining} = ExRated.check_rate(name, timeframe, requests)

    case status do
      :ok ->
        :ok

      :error ->
        warn("ratelimited; sleeping for 500ms")
        _ = Process.sleep(500)
        block_while_limited(bucket_info)
    end
  end

  def call(env, next, bucket_info) do
    :ok = block_while_limited(bucket_info)

    Tesla.run(env, next)
  end
end
