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

  @spec format([{result_type(), Card.t() | {Card.t(), [Ruling.t()]}}] | %Stream{}) :: [Embed.t()]
  def format(cards) do
    debug(inspect(cards))

    t =
      for {type, info} <- cards do
        case info do
          {card, rulings} ->
            format(type, card, rulings)

          card ->
            debug("LT " <> inspect(type))
            f = format(type, card)
            debug("L " <> inspect(f))
            f
        end
      end
      |> List.flatten()

    debug("FT " <> inspect(t))
    t
  end

  @spec format(result_type(), Card.t(), [Ruling.t()]) :: Embed.t() | [Embed.t()]
  def format(:card, card, card_rulings) do
    case fits_limits?(card, card_rulings) do
      true ->
        rulings(format(:card, card), card_rulings)

      false ->
        [
          %Embed{}
          |> Embed.put_title(md_escape(card.name))
          |> Embed.put_url(card.scryfall_uri)
          |> Embed.put_description(
            Emoji.emojify(card.mana_cost <> "\n" <> card_description(card))
          )
          |> legalities(card.legalities)
          |> Embed.put_thumbnail(card.image_uris.normal),
          %Embed{}
          |> rulings(card_rulings)
          |> Embed.put_footer(footer(), @scryfall_icon_uri)
        ]
    end
  end

  def format(type, _, _) do
    raise "Cannot apply rulings to a result of type #{inspect(type)}"
  end

  @spec format(result_type(), Card.t()) :: Embed.t() | [Embed.t()]
  def format(type, card)

  def format(:art, card) do
    warn(inspect(card))
    warn(inspect(card.card_faces))

    case card do
      %Card{card_faces: faces} when no(faces) ->
        %Embed{}
        |> Embed.put_color(Colors.success())
        |> Embed.put_title(card.name)
        |> Embed.put_field("Artist", card.artist)
        |> Embed.put_url(card.scryfall_uri)
        |> Embed.put_image(card.image_uris.art_crop)
        |> Embed.put_footer(footer(), @scryfall_icon_uri)

      _ ->
        card.card_faces
        |> Stream.map(fn x -> Map.merge(card, x) end)
        |> Stream.map(fn x -> Map.replace!(x, :card_faces, nil) end)
        |> Enum.map(fn x -> format(:art, x) end)
    end
  end

  def format(:card, card) do
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
        card.card_faces
        |> Stream.map(fn x -> Map.from_struct(x) end)
        |> Stream.map(
          fn x ->
            x
            |> Stream.filter(fn {_k, v} -> v != nil end)
            |> Enum.into(%{})
          end
        )
        |> Stream.map(fn x -> Map.merge(card, x) end)
        |> Stream.map(fn x -> Map.replace!(x, :card_faces, []) end)
        |> Stream.map(fn x -> Card.from_map(x) end)
        |> Enum.map(fn x -> format(:card, x) end)
    end
  end

  def format(:list, card) do
  end

  def format(:ambiguous, card) do
  end

  def format(:error, card) do
    card
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
          |> Enum.filter(fn {_, v} -> v == "legal" end)
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
  def md_escape(text) do
    text
    |> String.replace("_", "\\_")
    |> String.replace("~", "\\~")
    |> String.replace("*", "\\*")
    |> String.replace("`", "\\`")
    |> String.replace(">", "\\>")
  end

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

    power = card.power
    toughness = card.toughness

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
