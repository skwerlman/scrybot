defmodule Scrybot.Scryfall.Api do
  @moduledoc false
  @scryfall_uri "https://api.scryfall.com"
  use Tesla
  use Scrybot.LogMacros
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

  @type error :: {:error, Embed.t(), String.t()}

  plug(Tesla.Middleware.Telemetry)
  plug(Scrybot.Scryfall.Ratelimiter.Middleware, {:scryfall_bucket, 1000, 10})
  plug(Scrybot.Scryfall.Cache.Middleware)
  plug(Tesla.Middleware.BaseUrl, @scryfall_uri)
  plug(Tesla.Middleware.Retry, delay: 125, max_retries: 3)
  plug(Tesla.Middleware.Timeout, timeout: 10_000)
  plug(Tesla.Middleware.DecodeJson)

  defp handle_errors({:ok, %{body: body = %{"object" => _}, status: status} = resp}) do
    case body["object"] do
      "error" ->
        b = body
        code = b["code"]
        api_status = b["status"]

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
          |> Embed.put_footer("#{api_status} #{code}#{type} (#{status})", nil)

        {:error, reason, b["type"]}

      _ ->
        {:ok, resp}
    end
  end

  defp handle_errors({:ok, %{body: body, status: status}}) do
    error(inspect(body))

    {pstatus, parsed_body} = Floki.parse_document(body)

    {text, color} =
      case pstatus do
        :ok ->
          # body is _probably_ raw html, try to get the page title
          title =
            parsed_body
            |> Floki.find("head > title")
            |> Floki.text()

          txt =
            case title do
              t when is_binary(t) and t != "" ->
                """
                :warning: Unexpected reply from Scryfall:

                ```
                #{title}
                ```
                """

              "" ->
                """
                :warning: Unexpected reply from Scryfall!

                See the log for details.
                """
            end

          {txt, Colors.warning()}

        :error ->
          # body is not json or something floki understands, we have a problem
          txt = """
          :warning: Unparseable response recieved from scryfall!

          See the log for details.
          """

          {txt, Colors.error()}
      end

    reason =
      %Embed{}
      |> Embed.put_color(color)
      |> Embed.put_title("Error!")
      |> Embed.put_description(text)
      |> Embed.put_footer("HTTP #{status}", nil)

    {:error, reason, "NONJSONRESP"}
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
            "Can we get an F in chat for scryfall?"

          :invalid_uri ->
            "We seem to have generated a bad URI. Please report this bug."

          _ ->
            "Unknown error! (`#{inspect(status)}`)"
        end
      )
      |> Embed.put_footer("#{inspect(status)}", nil)

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

  @spec autocomplete(String.t(), [keyword]) :: {:ok, map} | error
  def autocomplete(partial_name, options \\ []) do
    query = [q: partial_name]
    res = get("/cards/autocomplete", query: query ++ options)
    res |> handle_errors()
  end
end
