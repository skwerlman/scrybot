defmodule Scrybot.Scryfall.Api do
  @moduledoc false
  @scryfall_uri "https://api.scryfall.com"
  use Tesla
  alias Nostrum.Struct.Embed
  require Logger

  plug(Scrybot.Cache.Middleware)
  plug(Tesla.Middleware.BaseUrl, @scryfall_uri)
  plug(Tesla.Middleware.Timeout, timeout: 2000)
  plug(Tesla.Middleware.Retry, delay: 125, max_retries: 3)
  plug(Tesla.Middleware.DecodeJson)

  defp handle_errors(resp) do
    case resp.body["object"] do
      "error" ->
        b = resp.body
        Logger.debug(inspect(b))
        code = b["code"]
        status = b["status"]

        type =
          case b["type"] do
            nil -> ""
            type -> " (#{type})"
          end

        reason =
          %Embed{}
          |> Embed.put_color(0xE74C3C)
          |> Embed.put_title("Error!")
          |> Embed.put_description(b["details"])
          |> Embed.put_footer("#{status} #{code}#{type}", nil)

        {:error, reason}

      _ ->
        {:ok, resp}
    end
  end

  def cards_named(card_name, use_exact) do
    query = [
      case use_exact do
        true -> {:exact, card_name}
        false -> {:fuzzy, card_name}
      end,
      format: "json"
    ]

    res = get("/cards/named", query: query)
    # IO.puts("got an answer: #{inspect(res)}")
    res |> handle_errors()
  end

  def rulings(cardid) do
    query = [format: "json"]
    res = get("/cards/#{cardid}/rulings", query: query)
    # IO.puts("got an answer: #{inspect(res)}")
    res |> handle_errors()
  end
end
