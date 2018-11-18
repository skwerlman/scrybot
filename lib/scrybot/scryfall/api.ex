defmodule Scrybot.Scryfall.Api do
  @moduledoc false
  @scryfall_uri "https://api.scryfall.com"
  use Tesla
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors
  require Logger

  plug(Scrybot.Cache.Middleware)
  plug(Tesla.Middleware.BaseUrl, @scryfall_uri)
  plug(Tesla.Middleware.Timeout, timeout: 2000)
  plug(Tesla.Middleware.Retry, delay: 125, max_retries: 3)
  plug(Tesla.Middleware.DecodeJson)

  def setup do
    _ = :ets.new(:scryfall_queue_data, [:set, :public, :named_table])
    {:ok, opq} = OPQ.init(workers: 1, interval: 60, timeout: 60_000)
    :ets.insert(:scryfall_queue_data, {:opq, opq})
  end

  defp getval(rkey) do
    [{_, state}] = :ets.lookup(:scryfall_queue_data, {rkey, :status})
    getval(rkey, state)
  end

  defp getval(rkey, :queued) do
    Process.sleep(60)
    [{_, state}] = :ets.lookup(:scryfall_queue_data, {rkey, :status})
    getval(rkey, state)
  end

  defp getval(rkey, :running) do
    Process.sleep(6)
    [{_, state}] = :ets.lookup(:scryfall_queue_data, {rkey, :status})
    getval(rkey, state)
  end

  defp getval(rkey, :done) do
    [{_, resp}] = :ets.lookup(:scryfall_queue_data, {rkey, :response})
    resp
  end

  def ratelimited_get(url, query) do
    [{:opq, opq}] = :ets.lookup(:scryfall_queue_data, :opq)

    request_key = UUID.uuid4()

    :ets.insert(:scryfall_queue_data, {{request_key, :status}, :queued})

    OPQ.enqueue(opq, fn ->
      :ets.insert(:scryfall_queue_data, {{request_key, :status}, :running})
      # this is Tesla's get
      response = get(url, query)
      :ets.insert(:scryfall_queue_data, {{request_key, :response}, response})
      :ets.insert(:scryfall_queue_data, {{request_key, :status}, :done})
    end)

    resp = getval(request_key)

    :ets.delete(:scryfall_queue_data, {request_key, :status})
    :ets.delete(:scryfall_queue_data, {request_key, :response})

    resp
  end

  defp handle_errors({:ok, resp}) do
    case resp.body["object"] do
      "error" ->
        b = resp.body
        code = b["code"]
        status = b["status"]

        type =
          case b["type"] do
            nil -> ""
            type -> " (#{type})"
          end

        reason =
          %Embed{}
          |> Embed.put_color(Colors.error())
          |> Embed.put_title("Error!")
          |> Embed.put_description(b["details"])
          |> Embed.put_footer("#{status} #{code}#{type}", nil)

        {:error, reason, b["type"]}

      _ ->
        {:ok, resp}
    end
  end

  defp handle_errors({:error, status}) do
    reason =
      %Embed{}
      |> Embed.put_color(Colors.error())
      |> Embed.put_title("Scryfall API error!")
      |> Embed.put_description(
        case status do
          :econnrefused ->
            "Connection refused!"

          :timeout ->
            "Connection timed out!"

          _ ->
            "Unknown error!"
        end
      )
      |> Embed.put_footer("#{status}", nil)

    {:error, reason}
  end

  def cards_named(card_name, use_exact) do
    query = [
      case use_exact do
        true -> {:exact, card_name}
        false -> {:fuzzy, card_name}
      end,
      format: "json"
    ]

    res = ratelimited_get("/cards/named", query: query)
    # IO.puts("got an answer: #{inspect(res)}")
    res |> handle_errors()
  end

  def rulings(cardid) do
    query = [format: "json"]
    res = ratelimited_get("/cards/#{cardid}/rulings", query: query)
    # IO.puts("got an answer: #{inspect(res)}")
    res |> handle_errors()
  end

  def autocomplete(partial) do
    query = [q: partial]
    res = ratelimited_get("/cards/autocomplete", query: query)
    res |> handle_errors()
  end
end
