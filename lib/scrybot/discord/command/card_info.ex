defmodule Scrybot.Discord.Command.CardInfo do
  @moduledoc false
  require Logger
  import Scrybot.LogMacros
  alias Nostrum.Api
  alias Nostrum.Struct.{Embed, Message, User}
  alias Scrybot.Discord.{Colors, Emoji}
  alias Scrybot.Scryfall

  @behaviour Scrybot.Discord.Behaviour.Handler
  @behaviour Scrybot.Discord.Behaviour.CommandHandler

  @scryfall_icon_uri "https://cdn.discordapp.com/app-icons/268547439714238465/f13c4408ead703ef3940bc7e21b91e2b.png"

  @doc false
  @impl Scrybot.Discord.Behaviour.Handler
  def init do
    info("CardInfo command set loaded")
    :ok
  end

  @doc false
  @impl Scrybot.Discord.Behaviour.Handler
  def allow_bots?, do: false

  @doc """
  Scan the message for patterns like [[card name]] and look up info
  about each of those cards.
  """
  @impl Scrybot.Discord.Behaviour.CommandHandler
  def do_command(%Message{author: %User{bot: bot}} = message) when bot in [false, nil] do
    ~r/(?:\[\[(.*?)\]\])/
    |> Regex.scan(message.content)
    # Regex.scan returns results as a list of lists
    # We only care about the second capture, so we strip off the rest
    |> Stream.map(fn [_ | [x | _]] -> x end)
    # Its possible for the above filter to return an
    # empty list, so we remove it here
    |> Stream.reject(fn x -> x == [] end)
    # We only want to handle a given card once, so we filter for unique cards
    |> Stream.uniq()
    # Finally, we run handle_card on each of the cards
    # This is synchronous to avoid split responses being out-of-order
    |> Enum.each(fn x -> handle_card(x, message, :fuzzy) end)

    # Same as above, but handles exact-match [=[]]
    ~r/(?:\[=\[(.*?)\]\])/
    |> Regex.scan(message.content)
    |> Stream.map(fn [_ | [x | _]] -> x end)
    |> Stream.reject(fn x -> x == [] end)
    |> Stream.uniq()
    |> Enum.each(fn x -> handle_card(x, message, :exact) end)

    # Same as above, but handles searching [?[]]
    ~r/(?:\[\?\[(.*?)\]\])/
    |> Regex.scan(message.content)
    |> Stream.map(fn [_ | [x | _]] -> x end)
    |> Stream.reject(fn x -> x == [] end)
    |> Stream.uniq()
    |> Enum.each(fn x -> handle_search(x, message, :search) end)

    # Same as above, but handles edhrec searching [e[]]
    ~r/(?:\[e\[(.*?)\]\])/
    |> Regex.scan(message.content)
    |> Stream.map(fn [_ | [x | _]] -> x end)
    |> Stream.reject(fn x -> x == [] end)
    |> Stream.uniq()
    |> Enum.each(fn x -> handle_search(x, message, :edhrec) end)

    :ok
  end

  defp handle_card(card_name, ctx, :fuzzy) do
    card_name |> get_card_info() |> handle_maybe_ambiguous(card_name, ctx)
  end

  defp handle_card(card_name, ctx, :exact) do
    card_name |> get_exact_card_info() |> handle_maybe_ambiguous(card_name, ctx)
  end

  defp handle_card(card_name, ctx, :ambiguous) do
    card_name
    |> get_alternate_cards()
    |> return_alternate_cards(card_name, ctx)
  end

  defp handle_card(card_info, ctx) do
    case card_info do
      {:ok, info} ->
        rulings =
          case get_rulings(info.body["id"]) do
            {:ok, %{body: resp}} -> resp["data"]
            {:error, reason} -> notify_error(reason, ctx.channel_id)
          end

        return_card(info, rulings, ctx)

      {:error, message, _} ->
        return_error(message, ctx)

      {:error, message} ->
        return_error(message, ctx)
    end
  end

  defp handle_search(search_term, ctx, :search) do
    search_term |> get_search_info() |> handle_search_results(ctx)
  end

  defp handle_search(search_term, ctx, :edhrec) do
    search_term |> get_edhrec_search_info() |> handle_search_results(ctx, :edhrec)
  end

  defp handle_search_results(results, ctx, mode \\ :search)

  defp handle_search_results({:ok, results}, ctx, mode) do
    return_search_results(results, ctx, mode)
  end

  defp handle_search_results({:error, reason}, ctx, _mode) do
    notify_error(reason, ctx.channel_id)
  end

  defp handle_maybe_ambiguous(card_info, card_name, ctx) do
    case card_info do
      {:error, _, "ambiguous"} -> handle_card(card_name, ctx, :ambiguous)
      _ -> handle_card(card_info, ctx)
    end
  end

  defp put_rulings(embed, []), do: embed

  defp put_rulings(embed, [ruling | rulings]) do
    embed
    |> Embed.put_field("Ruling #{ruling["published_at"]}", Emoji.emojify(ruling["comment"]))
    |> put_rulings(rulings)
  end

  defp put_legalities(embed, legalities) do
    case legalities do
      nil ->
        embed

      _ ->
        legal_formats =
          legalities
          |> Map.to_list()
          |> Enum.filter(fn {_, v} -> v == "legal" end)
          |> Enum.map(fn {k, _} -> "- #{k}" end)

        # Take every other entry, starting with the 0th
        legal_group_1 =
          legal_formats
          |> Enum.take_every(2)
          |> Enum.join("\n")

        # Take every other entry, starting witht the 1st
        legal_group_2 =
          legal_formats
          |> Enum.drop(1)
          |> Enum.take_every(2)
          |> Enum.join("\n")

        case {legal_group_1, legal_group_2} do
          {"", ""} ->
            # There are no legal formats
            embed

          {_, ""} ->
            # There is exactly one legal format
            embed
            |> Embed.put_field("Legal in", legal_group_1, true)

          {_, _} ->
            # There are at least 2 legal formats
            embed
            |> Embed.put_field("Legal in", legal_group_1, true)
            |> Embed.put_field("\u200D", legal_group_2, true)
        end
    end
  end

  defp format_description(card) do
    type = card["type_line"]

    text =
      case card["oracle_text"] do
        nil ->
          ""

        oracle ->
          oracle
          |> String.replace("\n", "\n\n")
          |> Emoji.emojify()
      end

    power = card["power"]
    toughness = card["toughness"]

    pt =
      if power && toughness do
        "**#{power}/#{toughness}**\n"
      else
        ""
      end

    case card["flavor_text"] do
      nil -> "**#{type}**\n#{pt}#{text}"
      flavor -> "**#{type}**\n#{pt}#{text}\n———\n_#{flavor}_"
    end
  end

  defp md_escape(text) do
    text
    |> String.replace("_", "\\_")
    |> String.replace("~", "\\~")
    |> String.replace("*", "\\*")
    |> String.replace("`", "\\`")
    |> String.replace(">", "\\>")
  end

  defp fits_limits?(_info, rulings) do
    # TODO make this smarter
    # Currently this only checks if there are at least 5 rulings
    # Ideally, this would check based on the total length of the rulings
    #
    # The total max length of an embed is 6000 chars (not graphemes!)
    case length(rulings) do
      x when x <= 5 -> true
      _ -> false
    end
  end

  defp footer do
    case Enum.random(1..5000) do
      x when x in 1..4999 -> "data sourced from Scryfall"
      5000 -> "data forcefully ripped from the cold, dead hands of Scryfall"
    end
  end

  defp return_card(%{body: %{layout: layout} = body}, rulings, ctx)
       when layout in ["split", "flip", "transform", "double_faced_token"] do
    [last_face | faces] = body["card_faces"] |> Enum.reverse()

    for face <- faces |> Enum.reverse() do
      Map.merge(body, face)
    end
    |> Enum.each(fn x ->
      return_card(x, [], ctx)
    end)

    case last_face do
      nil ->
        :ok

      face ->
        return_card(Map.merge(body, face), rulings, ctx)
    end
  end

  defp return_card(%{body: info}, rulings, ctx) do
    return_card(info, rulings, ctx)
  end

  defp return_card(info, rulings, ctx) do
    embeds =
      case fits_limits?(info, rulings) do
        true ->
          [
            %Embed{}
            |> Embed.put_title(md_escape(info["name"]))
            |> Embed.put_url(info["scryfall_uri"])
            |> Embed.put_description(
              Emoji.emojify(info["mana_cost"] <> "\n" <> format_description(info))
            )
            |> put_legalities(info["legalities"])
            |> Embed.put_thumbnail(info["image_uris"]["small"])
            |> put_rulings(rulings)
            |> Embed.put_footer(footer(), @scryfall_icon_uri)
          ]

        false ->
          [
            %Embed{}
            |> Embed.put_title(md_escape(info["name"]))
            |> Embed.put_url(info["scryfall_uri"])
            |> Embed.put_description(
              Emoji.emojify(info["mana_cost"] <> "\n" <> format_description(info))
            )
            |> put_legalities(info["legalities"])
            |> Embed.put_thumbnail(info["image_uris"]["normal"]),
            %Embed{}
            |> put_rulings(rulings)
            |> Embed.put_footer(footer(), @scryfall_icon_uri)
          ]
      end

    for embed <- embeds do
      Api.create_message(ctx.channel_id, embed: embed)
    end
  end

  defp return_alternate_cards({:error, message}, _, ctx), do: return_error(message, ctx)

  defp return_alternate_cards({:ok, resp}, card_name, ctx) do
    card_list =
      resp.body["data"]
      |> Enum.map(fn x -> "- #{x}" end)
      |> Enum.join("\n")

    embed =
      %Embed{}
      |> Embed.put_color(Colors.warning())
      |> Embed.put_title("Ambiguous card name")
      |> Embed.put_description("""
      The name \"#{card_name}\" matches too many cards.
      Did you mean one of these?

      #{card_list}
      """)

    Api.create_message(ctx.channel_id, embed: embed)
  end

  defp return_search_results(%{body: results}, ctx, :search) do
    # debug(inspect(results))

    card_list =
      results["data"]
      |> Enum.to_list()
      |> Enum.map(fn x -> "- #{x["name"]}" end)
      |> Enum.take(50)

    msg_body =
      card_list
      |> Enum.join("\n")

    embed =
      %Embed{}
      |> Embed.put_color(Colors.info())
      |> Embed.put_title("Search Results (#{length(card_list)} of #{results["total_cards"]})")
      |> Embed.put_description("#{msg_body}")

    Api.create_message(ctx.channel_id, embed: embed)
  end

  defp return_search_results(%{body: results}, ctx, :edhrec) do
    # debug(inspect(results))

    card_list =
      results["data"]
      |> Enum.to_list()
      |> Enum.map(fn x -> "- #{x["name"]} (##{x["edhrec_rank"]})" end)
      |> Enum.take(50)

    msg_body =
      card_list
      |> Enum.join("\n")

    embed =
      %Embed{}
      |> Embed.put_color(Colors.info())
      |> Embed.put_title(
        "EDHREC Search Results (#{length(card_list)} of #{results["total_cards"]})"
      )
      |> Embed.put_description("#{msg_body}")

    Api.create_message(ctx.channel_id, embed: embed)
  end

  defp return_error(message, ctx) do
    Api.create_message(ctx.channel_id, embed: message)
  end

  defp notify_error(reason, channel) do
    error(inspect(reason))
    Api.create_message(channel, embed: reason)
  end

  defp get_alternate_cards(card_name) do
    Scryfall.Api.autocomplete(card_name)
  end

  defp get_search_info(card_name) do
    Scryfall.Api.cards_search(card_name)
  end

  defp get_edhrec_search_info(card_name) do
    Scryfall.Api.cards_search(card_name, order: "edhrec")
  end

  defp get_exact_card_info(card_name) do
    Scryfall.Api.cards_named(card_name, true)
  end

  defp get_card_info(card_name) do
    Scryfall.Api.cards_named(card_name, false)
  end

  defp get_rulings(cardid) do
    Scryfall.Api.rulings(cardid)
  end
end
