defmodule Scrybot.Discord.Command.CardInfo do
  @moduledoc false
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User
  alias Scrybot.Discord.Colors
  alias Scrybot.Discord.Emoji

  @doc false
  def init do
    Logger.info("CardInfoNew command set loaded")
  end

  @doc false
  def allow_bots?, do: false

  @doc """
  Scan the message for patterns like [[card name]] and look up info
  about each of those cards.
  """
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
    |> Enum.each(fn x -> handle_card(x, message) end)

    ~r/(?:\[e\[(.*?)\]\])/
    |> Regex.scan(message.content)
    |> Stream.map(fn [_ | [x | _]] -> x end)
    |> Stream.reject(fn x -> x == [] end)
    |> Stream.uniq()
    |> Enum.each(fn x -> handle_exact_card(x, message) end)
  end

  defp handle_exact_card(card_name, ctx) do
    card_info =
      card_name
      |> get_exact_card_info()

    case card_info do
      {:ok, info} ->
        rulings =
          case get_rulings(info.body["id"]) do
            {:ok, %{body: resp}} -> resp["data"]
            {:error, reason} -> notify_error(reason, ctx.channel_id)
          end

        return_card(info, rulings, ctx)

      {:error, _, "ambiguous"} ->
        card_name
        |> get_alternate_cards()
        |> return_alternate_cards(card_name, ctx)

      {:error, message, _} ->
        return_error(message, ctx)

      {:error, message} ->
        return_error(message, ctx)
    end
  end

  defp handle_card(card_name, ctx) do
    card_info =
      card_name
      |> get_card_info()

    case card_info do
      {:ok, info} ->
        rulings =
          case get_rulings(info.body["id"]) do
            {:ok, %{body: resp}} -> resp["data"]
            {:error, reason} -> notify_error(reason, ctx.channel_id)
          end

        return_card(info, rulings, ctx)

      {:error, _, "ambiguous"} ->
        card_name
        |> get_alternate_cards()
        |> return_alternate_cards(card_name, ctx)

      {:error, message, _} ->
        return_error(message, ctx)

      {:error, message} ->
        return_error(message, ctx)
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

        legal_group_1 =
          legal_formats
          |> Enum.take_every(2)
          |> Enum.join("\n")

        legal_group_2 =
          legal_formats
          |> Enum.drop(1)
          |> Enum.take_every(2)
          |> Enum.join("\n")

        case {legal_group_1, legal_group_2} do
          {"", ""} ->
            embed

          {_, ""} ->
            embed
            |> Embed.put_field("Legal in", legal_group_1, true)

          {_, _} ->
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
    case length(rulings) do
      x when x <= 5 -> true
      _ -> false
    end
  end

  defp return_card(%{body: %{"layout" => layout} = body}, rulings, ctx)
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
        return_card(face, rulings, ctx)
    end
  end

  defp return_card(card_info, rulings, ctx) do
    info = card_info.body

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
            |> Embed.put_image(info["image_uris"]["small"])
            |> put_rulings(rulings)
            |> Embed.put_footer(
              case Enum.random(1..5000) do
                x when x in 1..4999 -> "data sourced from Scryfall"
                5000 -> "data forcefully ripped from the cold, dead hands of Scryfall"
              end,
              "https://cdn.discordapp.com/app-icons/268547439714238465/f13c4408ead703ef3940bc7e21b91e2b.png"
            )
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
            |> Embed.put_image(info["image_uris"]["art_crop"]),
            %Embed{}
            |> put_rulings(rulings)
            |> Embed.put_footer(
              case Enum.random(1..5000) do
                x when x in 1..4999 -> "data sourced from Scryfall"
                5000 -> "data forcefully ripped from the cold, dead hands of Scryfall"
              end,
              "https://cdn.discordapp.com/app-icons/268547439714238465/f13c4408ead703ef3940bc7e21b91e2b.png"
            )
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

  defp return_error(message, ctx) do
    Api.create_message(ctx.channel_id, embed: message)
  end

  defp get_alternate_cards(card_name) do
    Scrybot.Scryfall.Api.autocomplete(card_name)
  end

  defp get_exact_card_info(card_name) do
    Scrybot.Scryfall.Api.cards_named(card_name, true)
  end

  defp get_card_info(card_name) do
    Scrybot.Scryfall.Api.cards_named(card_name, false)
  end

  defp get_rulings(cardid) do
    Scrybot.Scryfall.Api.rulings(cardid)
  end

  defp notify_error(reason, channel) do
    Logger.error(inspect(reason))
    Nostrum.Api.create_message(channel, embed: reason)
  end
end
