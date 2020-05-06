defmodule Scrybot.Scryfall.Api do
  @moduledoc false
  @scryfall_uri "https://api.scryfall.com"
  use Tesla
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

  @type error :: {:error, Embed.t(), String.t()}

  plug(Scrybot.Scryfall.Ratelimiter.Middleware, {:scryfall_bucket, 1000, 10})
  plug(Scrybot.Scryfall.Cache.Middleware)
  plug(Tesla.Middleware.BaseUrl, @scryfall_uri)
  plug(Tesla.Middleware.Timeout, timeout: 4000)
  plug(Tesla.Middleware.Retry, delay: 125, max_retries: 3)
  plug(Tesla.Middleware.DecodeJson)

  defp handle_errors({:ok, %{body: body} = resp}) do
    case resp.body["object"] do
      "error" ->
        b = body
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

    {:error, reason, ""}
  end

  @spec cards_search(String.t(), [keyword]) :: {:ok, map} | error
  def cards_search(card_name, options \\ []) do
    query = [
      q: card_name,
      format: "json"
    ]

    res = get("/cards/search", query: query ++ options)
    # IO.puts("got an answer: #{inspect(res)}")
    res |> handle_errors()
  end

  @spec cards_named(String.t(), boolean, [keyword]) :: {:ok, map} | error
  def cards_named(card_name, use_exact, options \\ []) do
    query = [
      case use_exact do
        true -> {:exact, card_name}
        false -> {:fuzzy, card_name}
      end,
      format: "json"
    ]

    res = get("/cards/named", query: query ++ options)
    # IO.puts("got an answer: #{inspect(res)}")
    res |> handle_errors()
  end

  @spec rulings(String.t()) :: {:ok, map} | error
  def rulings(card_id) do
    query = [format: "json"]
    res = get("/cards/#{card_id}/rulings", query: query)
    # IO.puts("got an answer: #{inspect(res)}")
    res |> handle_errors()
  end

  @spec autocomplete(String.t()) :: {:ok, map} | error
  def autocomplete(partial_name) do
    query = [q: partial_name]
    res = get("/cards/autocomplete", query: query)
    res |> handle_errors()
  end
end
