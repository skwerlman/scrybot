defmodule Scrybot.Discord.Command.CardInfo.Formatter do
  @moduledoc false
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.{Colors, Emoji}
  alias Scrybot.Discord.Command.CardInfo.{Card, Ruling}
  alias Scrybot.Discord.Command.CardInfo.Card.Face
  use Scrybot.LogMacros

  defguardp no(faces) when faces == [] or is_nil(faces)

  @scryfall_icon_uri "https://cdn.discordapp.com/app-icons/268547439714238465/f13c4408ead703ef3940bc7e21b91e2b.png"

  @type failure_type :: :ambiguous | :error
  @type result_type :: :art | :card | :list | failure_type

  @type error :: Scrybot.Scryfall.Api.error()
  @type info :: Card.t() | error()

  # credo:disable-for-next-line Credo.Check.Warning.SpecWithStruct
  @spec format(
          [
            {result_type(),
             Card.t() | {Card.t(), keyword()} | {Card.t(), keyword(), [Ruling.t()]}}
          ]
          | %Stream{}
        ) :: [Embed.t()]
  def format(cards) do
    for {type, info} <- cards do
      case info do
        {card, meta, rulings} -> format(type, card, meta, rulings)
        {card, meta} -> format(type, card, meta)
        card -> format(type, card, [])
      end
    end
    |> List.flatten()
  end

  @spec format(result_type(), Card.t(), keyword(), [Ruling.t()]) :: Embed.t() | [Embed.t()]
  def format(:card, card, meta, card_rulings) do
    case fits_limits?(card, card_rulings) do
      true ->
        rulings(format(:card, card, meta), card_rulings)

      false ->
        [
          format(:card, card, meta),
          %Embed{}
          |> rulings(card_rulings)
          |> Embed.put_footer(footer(), @scryfall_icon_uri)
        ]
    end
  end

  def format(type, _, _, _) do
    raise "Cannot apply rulings to a result of type #{inspect(type)}"
  end

  @spec format(result_type(), Card.t(), keyword()) :: Embed.t() | [Embed.t()]
  def format(:art, card, meta) do
    warn(inspect(card))
    warn(inspect(card.card_faces))

    case card do
      %Card{card_faces: faces} when no(faces) ->
        %Embed{}
        |> Embed.put_color(Colors.success())
        |> Embed.put_title("#{card.name} (#{card.set |> String.upcase()})")
        |> Embed.put_field("Artist", card.artist)
        |> Embed.put_url(card.scryfall_uri)
        |> Embed.put_image(card.image_uris.art_crop)
        |> Embed.put_footer(footer(), @scryfall_icon_uri)

      _ ->
        flat_format(:art, card, meta)
    end
  end

  def format(:card, card, meta) do
    case card do
      %Card{card_faces: faces} when no(faces) ->
        %Embed{}
        |> Embed.put_title(md_escape(card.name))
        |> Embed.put_url(card.scryfall_uri)
        |> Embed.put_description(Emoji.emojify(card.mana_cost <> "\n" <> card_description(card)))
        |> legalities(card.legalities)
        |> Embed.put_thumbnail(card.image_uris.normal)
        |> Embed.put_footer(footer(), @scryfall_icon_uri)

      _ ->
        flat_format(:card, card, meta)
    end
  end

  def format(:list, resp, _meta) do
    card_list =
      resp["data"]
      |> Enum.map(fn x -> x["name"] end)
      |> Enum.take(50)

    count = resp["total_cards"]
    count2 = card_list |> Enum.count()

    %Embed{}
    |> Embed.put_color(Colors.success())
    |> Embed.put_title("Showing results 1-#{count2} of #{count}")
    |> Embed.put_description(card_list |> Enum.join("\n"))
  end

  def format(:ambiguous, resp, query: query) do
    info("HERE " <> inspect(resp))
    info("Q #{inspect(resp.query)}")

    card_list =
      resp.body["data"]
      |> Enum.map_join("\n", fn x -> "- #{x}" end)

    %Embed{}
    |> Embed.put_color(Colors.warning())
    |> Embed.put_title("Ambiguous query")
    |> Embed.put_description("""
    The query \"#{query}\" matches too many cards.
    Did you mean one of these?

    #{card_list}
    """)
  end

  def format(:rule, rules, _meta) do
    for {:rule, {type, rule, body, examples}} <- rules do
      type_name =
        type
        |> Atom.to_string()
        |> String.capitalize()

      rule_name =
        rule
        |> LibJudge.Rule.to_string!()

      footer_string = "Data from the Magic: The Gathering Comprehensive Rules"

      embed =
        %Embed{}
        |> Embed.put_color(Colors.success())
        |> Embed.put_title("#{type_name} #{rule_name}")
        |> Embed.put_description(body)
        |> Embed.put_footer(footer_string)

      case examples do
        [] ->
          embed

        _ ->
          examples
          |> Enum.reduce(embed, &Embed.put_field(&2, "Example", &1))
      end
    end
  end

  def format(:error, card, _meta) do
    card
  end

  defp flat_format(type, card = %Card{layout: "double_faced_token"}, meta = [query: query]) do
    debug("DFT")
    debug(inspect(card))

    card.card_faces
    |> Stream.map(fn face ->
      if Scrybot.DamerauLevenshtein.equivalent?(
           face.name,
           query,
           Integer.floor_div(String.length(query), 4)
         ) or String.contains?(query, "/") do
        debug("MATCH")
        Map.merge(card, face)
      end
    end)
    |> Stream.filter(fn
      nil -> false
      _ -> true
    end)
    |> Stream.map(fn x -> Map.from_struct(x) end)
    |> Stream.map(fn x ->
      x
      |> Stream.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})
    end)
    |> Stream.map(fn x -> Map.replace!(x, :card_faces, []) end)
    |> Stream.map(fn x -> Map.replace!(x, :object, "card") end)
    |> Stream.map(fn x -> Map.replace!(x, :layout, "REPLACED_DFT") end)
    |> Stream.map(fn x -> Card.from_map(x) end)
    |> Stream.filter(fn x -> Card.valid?(x) end)
    |> Enum.map(fn x -> format(type, x, meta) end)
  end

  defp flat_format(type, card, meta) do
    card.card_faces
    |> Stream.map(fn x -> Map.from_struct(x) end)
    |> Stream.map(fn x ->
      x
      |> Stream.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})
    end)
    |> Stream.map(fn x -> Map.merge(card, x) end)
    |> Stream.map(fn x -> Map.replace!(x, :card_faces, []) end)
    |> Stream.map(fn x -> Map.replace!(x, :object, "card") end)
    |> Stream.map(fn x -> Card.from_map(x) end)
    |> Stream.filter(fn x -> Card.valid?(x) end)
    |> Enum.map(fn x -> format(type, x, meta) end)
  end

  @spec rulings(Embed.t(), [Ruling.t()]) :: Embed.t()
  def rulings(embed, []), do: embed

  def rulings(embed, [ruling | rulings]) do
    embed
    |> Embed.put_field("Ruling #{ruling["published_at"]}", Emoji.emojify(ruling["comment"]))
    |> rulings(rulings)
  end

  @spec legalities(Embed.t(), %{required(atom) => String.t()}) :: Embed.t()
  def legalities(embed, legalities) do
    case legalities do
      nil ->
        embed

      _ ->
        legal_formats =
          legalities
          |> Map.to_list()
          |> Stream.filter(fn {_, v} -> v == "legal" end)
          |> Enum.map(fn {k, _} -> "- #{k}" end)

        # Take every other entry, starting with the 0th
        legal_group_1 =
          legal_formats
          |> Stream.take_every(2)
          |> Enum.join("\n")

        # Take every other entry, starting witht the 1st
        legal_group_2 =
          legal_formats
          |> Stream.drop(1)
          |> Stream.take_every(2)
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

  @spec footer() :: String.t()
  def footer do
    case Enum.random(1..5000) do
      2500 -> "data forcefully ripped from the cold, dead hands of Scryfall"
      _ -> "data sourced from Scryfall"
    end
  end

  @spec md_escape(String.t()) :: String.t()
  def md_escape(text) when is_binary(text) do
    text
    |> String.replace("_", "\\_")
    |> String.replace("~", "\\~")
    |> String.replace("*", "\\*")
    |> String.replace("`", "\\`")
    |> String.replace(">", "\\>")
  end

  def md_escape(x), do: x

  @spec fits_limits?(Card.t(), [String.t()]) :: boolean
  def fits_limits?(_info, rulings) do
    # TODO make this smarter
    # Currently this only checks if there are more than 5 rulings
    # Ideally, this would check based on the total length of the rulings
    #
    # The total max length of an embed is 6000 chars (not graphemes!)
    case length(rulings) do
      x when x <= 5 -> true
      _ -> false
    end
  end

  @spec card_description(Card.t() | Face.t()) :: String.t()
  def card_description(card) do
    type = card.type_line

    text =
      case card.oracle_text do
        nil ->
          ""

        oracle ->
          oracle
          |> String.replace("\n", "\n\n")
          |> Emoji.emojify()
      end

    power = md_escape(card.power)
    toughness = md_escape(card.toughness)

    pt =
      if power && toughness do
        "**#{power}/#{toughness}**\n"
      else
        ""
      end

    case card.flavor_text do
      nil -> "**#{type}**\n#{pt}#{text}"
      flavor -> "**#{type}**\n#{pt}#{text}\n———\n_#{flavor}_"
    end
  end
end
