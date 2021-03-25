defmodule Scrybot.Discord.Command.CardInfo.Card do
  @moduledoc false
  use Scrybot.LogMacros
  import Scrybot.Discord.Command.CardInfo.Validator
  alias Scrybot.Discord.Command.CardInfo.Card.{Face, Related}

  @type preview :: %{
          previewed_at: String.t(),
          source_uri: String.t(),
          source: String.t()
        }

  @type price_source :: :usd | :usd_foil | :eur | :tix

  @type marketplace :: :cardhoarder | :cardmarket | :tcgplayer

  @type info_source :: :edhrec | :gatherer | :mtgtop8 | :tcgplayer_decks

  @type t :: %__MODULE__{
          all_parts: [Related.t()] | nil,
          arena_id: non_neg_integer | nil,
          artist: String.t() | nil,
          booster: boolean,
          border_color: String.t(),
          card_back_id: String.t(),
          card_faces: [Face.t()],
          cmc: float,
          collector_number: String.t(),
          color_identity: [String.t()],
          color_indicator: [String.t()] | nil,
          colors: [String.t()] | nil,
          digital: boolean,
          edhrec_rank: non_neg_integer | nil,
          flavor_text: String.t() | nil,
          foil: boolean,
          frame: String.t(),
          frame_effects: [String.t()] | nil,
          full_art: boolean,
          games: [String.t()],
          hand_modifier: String.t() | nil,
          highres_image: boolean,
          id: String.t(),
          illustration_id: String.t() | nil,
          image_uris: %{required(atom) => String.t()} | nil,
          lang: String.t(),
          layout: String.t(),
          legalities: %{required(atom) => String.t()},
          life_modifier: String.t() | nil,
          loyalty: String.t() | nil,
          mana_cost: String.t() | nil,
          mtgo_foil_id: non_neg_integer | nil,
          mtgo_id: non_neg_integer | nil,
          multiverse_ids: [non_neg_integer] | nil,
          name: String.t(),
          nonfoil: boolean,
          object: String.t(),
          oracle_id: String.t(),
          oracle_text: String.t() | nil,
          oversized: boolean,
          power: String.t() | nil,
          preview: preview | nil,
          prices: %{required(price_source) => String.t()} | nil,
          printed_name: String.t() | nil,
          printed_text: String.t() | nil,
          printed_type_line: String.t() | nil,
          prints_search_uri: String.t(),
          promo: boolean,
          promo_types: [String.t()] | nil,
          purchase_uris: %{required(marketplace) => String.t()},
          rarity: String.t(),
          related_uris: %{required(info_source) => String.t()},
          released_at: String.t(),
          reprint: boolean,
          reserved: boolean,
          rulings_uri: String.t(),
          scryfall_set_uri: String.t(),
          scryfall_uri: String.t(),
          set: String.t(),
          set_name: String.t(),
          set_search_uri: String.t(),
          set_type: String.t(),
          set_uri: String.t(),
          story_spotlight: boolean,
          tcgplayer_id: non_neg_integer | nil,
          textless: boolean,
          toughness: String.t() | nil,
          type_line: String.t(),
          uri: String.t(),
          variation: boolean,
          variation_of: String.t() | nil,
          watermark: String.t()
        }

  @enforce_keys [
    :booster,
    :border_color,
    :card_back_id,
    :cmc,
    :collector_number,
    :color_identity,
    :digital,
    :foil,
    :frame,
    :full_art,
    :games,
    :highres_image,
    :id,
    :lang,
    :layout,
    :legalities,
    :name,
    :nonfoil,
    :object,
    :oracle_id,
    :oversized,
    :prices,
    :prints_search_uri,
    :promo,
    :purchase_uris,
    :rarity,
    :related_uris,
    :released_at,
    :reprint,
    :reserved,
    :rulings_uri,
    :scryfall_set_uri,
    :scryfall_uri,
    :set,
    :set_name,
    :set_search_uri,
    :set_type,
    :set_uri,
    :story_spotlight,
    :textless,
    :type_line,
    :uri,
    :variation
  ]

  defstruct [
    :all_parts,
    :arena_id,
    :artist,
    :booster,
    :border_color,
    :card_back_id,
    :card_faces,
    :cmc,
    :collector_number,
    :color_identity,
    :color_indicator,
    :colors,
    :digital,
    :edhrec_rank,
    :flavor_text,
    :foil,
    :frame,
    :frame_effects,
    :full_art,
    :games,
    :hand_modifier,
    :highres_image,
    :id,
    :illustration_id,
    :image_uris,
    :lang,
    :layout,
    :legalities,
    :life_modifier,
    :loyalty,
    :mana_cost,
    :mtgo_foil_id,
    :mtgo_id,
    :multiverse_ids,
    :name,
    :nonfoil,
    :object,
    :oracle_id,
    :oracle_text,
    :oversized,
    :power,
    :preview,
    :prices,
    :printed_name,
    :printed_text,
    :printed_type_line,
    :prints_search_uri,
    :promo,
    :promo_types,
    :purchase_uris,
    :rarity,
    :related_uris,
    :released_at,
    :reprint,
    :reserved,
    :rulings_uri,
    :scryfall_set_uri,
    :scryfall_uri,
    :set,
    :set_name,
    :set_search_uri,
    :set_type,
    :set_uri,
    :story_spotlight,
    :tcgplayer_id,
    :textless,
    :toughness,
    :type_line,
    :uri,
    :variation,
    :variation_of,
    :watermark
  ]

  @spec valid?(__MODULE__.t()) :: boolean
  def valid?(card) do
    debug("validating card #{inspect(card.name)}")

    {_, valid} =
      card
      |> Map.to_list()
      |> Enum.map_reduce(true, fn {k, v}, acc -> {v, acc && valid?(k, v)} end)

    debug("done: #{inspect(valid)}")

    valid
  end

  # alright credo shut the fuck up about cyclomatic complexity
  # i know this is just one big case but id rather that than
  # 70-odd pattern-matched function heads
  # its already fucking long enough without rewriting
  # "defp valid?(:some_atom, value) do" 400 fucking times
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp valid?(key, value) do
    debug("checking card key #{inspect(key)}")

    valid =
      case key do
        :all_parts ->
          (&Related.valid?/1)
          |> list_of()
          |> nilable()
          |> validate(value)

        :arena_id ->
          non_neg_integer()
          |> nilable()
          |> validate(value)

        :artist ->
          printable()
          |> nilable()
          |> validate(value)

        :booster ->
          is_boolean(value)

        :border_color ->
          value in ["black", "borderless", "gold", "silver", "white"]

        :card_back_id ->
          uuid().(value)

        :card_faces ->
          (&Face.valid?/1)
          |> list_of()
          |> nilable()
          |> validate(value)

        :cmc ->
          is_number(value)

        :collector_number ->
          printable().(value)

        :color_identity ->
          color()
          |> list_of()
          |> validate(value)

        :color_indicator ->
          color()
          |> list_of()
          |> nilable()
          |> validate(value)

        :colors ->
          color()
          |> list_of()
          |> nilable()
          |> validate(value)

        :digital ->
          is_boolean(value)

        :edhrec_rank ->
          non_neg_integer()
          |> nilable()
          |> validate(value)

        :flavor_text ->
          printable()
          |> nilable()
          |> validate(value)

        :foil ->
          is_boolean(value)

        :frame ->
          value in ["1993", "1997", "2003", "2015", "future"]

        :frame_effects ->
          fn x ->
            x in [
              "legendary",
              "miracle",
              "nyxtouched",
              "draft",
              "devoid",
              "tombstone",
              "colorshifted",
              "sunmoondfc",
              "compasslanddfc",
              "originpwdfc",
              "mooneldrazidfc",
              "moonreversemoondfc",
              "showcase",
              "extendedart",
              nil
            ]
          end
          |> list_of()
          |> validate(value)

        :full_art ->
          is_boolean(value)

        :games ->
          fn x -> x in ["paper", "arena", "mtgo"] end
          |> list_of()
          |> validate(value)

        :hand_modifier ->
          printable()
          |> nilable()
          |> validate(value)

        :highres_image ->
          is_boolean(value)

        :id ->
          uuid().(value)

        :illustration_id ->
          uuid()
          |> nilable()
          |> validate(value)

        :image_uris ->
          (&is_atom/1)
          |> map_of(uri())
          |> nilable()
          |> validate(value)

        :lang ->
          printable().(value)

        :layout ->
          value in [
            "normal",
            "split",
            "flip",
            "transform",
            "meld",
            "leveler",
            "saga",
            "adventure",
            "planar",
            "scheme",
            "vanguard",
            "token",
            "double_faced_token",
            "emblem",
            "augment",
            "host",
            "art_series",
            "double_sided",
            # this one is used internally by the formatter
            "REPLACED_DFT"
          ]

        :legalities ->
          (&is_atom/1)
          |> map_of(fn v -> v in ["legal", "not_legal", "restricted", "banned"] end)
          |> validate(value)

        :life_modifier ->
          printable()
          |> nilable()
          |> validate(value)

        :loyalty ->
          printable()
          |> nilable()
          |> validate(value)

        :mana_cost ->
          printable()
          |> nilable()
          |> validate(value)

        :mtgo_foil_id ->
          non_neg_integer()
          |> nilable()
          |> validate(value)

        :mtgo_id ->
          non_neg_integer()
          |> nilable()
          |> validate(value)

        :multiverse_ids ->
          non_neg_integer()
          |> list_of()
          |> nilable()
          |> validate(value)

        :name ->
          printable().(value)

        :nonfoil ->
          is_boolean(value)

        :object ->
          value == "card"

        :oracle_id ->
          uuid().(value)

        :oracle_text ->
          printable()
          |> nilable()
          |> validate(value)

        :oversized ->
          is_boolean(value)

        :power ->
          printable()
          |> nilable()
          |> validate(value)

        :preview ->
          map_of(
            fn k -> k in [:previewed_at, :source_uri, :source] end,
            printable()
          )
          |> nilable()
          |> validate(value)

        :prices ->
          map_of(
            fn k -> k in [:usd, :usd_foil, :eur, :tix] end,
            printable() |> nilable()
          )
          |> validate(value)

        :printed_name ->
          printable()
          |> nilable()
          |> validate(value)

        :printed_text ->
          printable()
          |> nilable()
          |> validate(value)

        :printed_type_line ->
          printable()
          |> nilable()
          |> validate(value)

        :prints_search_uri ->
          uri().(value)

        :promo ->
          is_boolean(value)

        :promo_types ->
          # TODO tighten this check a bit
          printable()
          |> list_of()
          |> nilable()
          |> validate(value)

        :purchase_uris ->
          map_of(
            fn k -> k in [:cardhoarder, :cardmarket, :tcgplayer] end,
            uri()
          )
          |> validate(value)

        :rarity ->
          value in ["common", "uncommon", "rare", "mythic"]

        :related_uris ->
          map_of(
            fn k -> k in [:edhrec, :gatherer, :mtgtop8, :tcgplayer_decks] end,
            uri()
          )
          |> validate(value)

        :released_at ->
          printable().(value)

        :reprint ->
          is_boolean(value)

        :reserved ->
          is_boolean(value)

        :rulings_uri ->
          uri().(value)

        :scryfall_set_uri ->
          uri().(value)

        :scryfall_uri ->
          uri().(value)

        :set ->
          printable().(value)

        :set_name ->
          printable().(value)

        :set_search_uri ->
          uri().(value)

        :set_type ->
          value in [
            "core",
            "expansion",
            "masters",
            "masterpiece",
            "from_the_vault",
            "spellbook",
            "premium_deck",
            "duel_deck",
            "draft_innovation",
            "treasure_chest",
            "commander",
            "planechase",
            "archenemy",
            "vanguard",
            "funny",
            "starter",
            "box",
            "promo",
            "token",
            "memorabilia"
          ]

        :set_uri ->
          uri().(value)

        :story_spotlight ->
          is_boolean(value)

        :tcgplayer_id ->
          non_neg_integer()
          |> nilable()
          |> validate(value)

        :textless ->
          is_boolean(value)

        :toughness ->
          printable()
          |> nilable()
          |> validate(value)

        :type_line ->
          printable().(value)

        :uri ->
          uri().(value)

        :variation ->
          is_boolean(value)

        :variation_of ->
          printable()
          |> nilable()
          |> validate(value)

        :watermark ->
          printable()
          |> nilable()
          |> validate(value)

        :__struct__ ->
          __MODULE__
      end

    if !valid do
      warn("key validation failed: #{inspect(key)} => #{inspect(value)}")
    end

    valid
  end

  @spec from_map(map) :: __MODULE__.t()
  def from_map(card), do: from_map(__MODULE__, card)

  @spec from_map(__MODULE__ | Face | Related, map) :: __MODULE__.t() | Face.t() | Related.t()
  def from_map(__MODULE__, card) do
    struct = struct(__MODULE__)

    Enum.reduce(Map.to_list(struct), struct, fn {k, _}, acc ->
      case {Map.fetch(card, Atom.to_string(k)), Map.fetch(card, k)} do
        {{:ok, v}, _} ->
          case k do
            :all_parts ->
              %{acc | k => for(v2 <- v, do: v2 |> atomify_map() |> Related.from_map())}

            :card_faces ->
              t = for(v2 <- v, do: v2 |> atomify_map() |> Face.from_map())
              %{acc | k => t}

            _ ->
              %{acc | k => atomify_map(v)}
          end

        {_, {:ok, v}} ->
          case {k, v} do
            {_, nil} ->
              acc

            {:all_parts, _} ->
              %{acc | k => for(v2 <- v, do: v2 |> atomify_map() |> Related.from_map())}

            {:card_faces, _} ->
              t = for(v2 <- v, do: v2 |> atomify_map() |> Face.from_map())
              %{acc | k => t}

            _ ->
              %{acc | k => atomify_map(v)}
          end

        {_, _} ->
          acc
      end
    end)
  end

  def from_map(mod, card) do
    struct = struct(mod)

    Enum.reduce(Map.to_list(struct), struct, fn {k, _}, acc ->
      case Map.fetch(card, k) do
        {:ok, v} -> %{acc | k => v}
        :error -> acc
      end
    end)
  end

  defp atomify_map(map) when is_map(map) do
    Enum.reduce(Map.to_list(map), %{}, fn {key, v}, acc ->
      case to_known_atom(key) do
        {:ok, k} -> Map.put_new(acc, k, v)
        :error -> acc
      end
    end)
  end

  defp atomify_map(term), do: term

  @known_atom_mapping %{
    "art_crop" => :art_crop,
    "artist" => :artist,
    "artist_id" => :artist,
    "border_crop" => :border_crop,
    "brawl" => :brawl,
    "cardhoarder" => :cardhoarder,
    "cardmarket" => :cardmarket,
    "color_indicator" => :color_indicator,
    "colors" => :colors,
    "commander" => :commander,
    "component" => :component,
    "duel" => :duel,
    "edhrec" => :edhrec,
    "eur" => :eur,
    "eur_foil" => :eur_foil,
    "flavor_text" => :flavor_text,
    "future" => :future,
    "gatherer" => :gatherer,
    "gladiator" => :gladiator,
    "historic" => :historic,
    "id" => :id,
    "illustration_id" => :illustration_id,
    "image_uris" => :image_uris,
    "large" => :large,
    "legacy" => :legacy,
    "loyalty" => :loyalty,
    "mana_cost" => :mana_cost,
    "modern" => :modern,
    "mtgtop8" => :mtgtop8,
    "name" => :name,
    "normal" => :normal,
    "object" => :object,
    "oldschool" => :oldschool,
    "oracle_text" => :oracle_text,
    "pauper" => :pauper,
    "penny" => :penny,
    "pioneer" => :pioneer,
    "png" => :png,
    "power" => :power,
    "premodern" => :premodern,
    "previewed_at" => :previewed_at,
    "printed_name" => :printed_name,
    "printed_type_line" => :printed_type_line,
    "small" => :small,
    "source_uri" => :source_uri,
    "source" => :source,
    "standard" => :standard,
    "tcgplayer_decks" => :tcgplayer_decks,
    "tcgplayer_infinite_articles" => :tcgplayer_infinite_articles,
    "tcgplayer_infinite_decks" => :tcgplayer_infinite_decks,
    "tcgplayer" => :tcgplayer,
    "tix" => :tix,
    "toughness" => :toughness,
    "type_line" => :type_line,
    "uri" => :uri,
    "usd_foil" => :usd_foil,
    "usd" => :usd,
    "vintage" => :vintage,
    "watermark" => :watermark
  }

  defp to_known_atom(atom) when is_atom(atom) do
    {:ok, atom}
  end

  defp to_known_atom(string) do
    case Map.fetch(@known_atom_mapping, string) do
      {:ok, atom} ->
        {:ok, atom}

      :error ->
        warn("/!\\ discarding unrecognized key #{inspect(string)}")
        :error
    end
  end
end
