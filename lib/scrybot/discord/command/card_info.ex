defmodule Scrybot.Discord.Command.CardInfo do
  @moduledoc false
  use Scrybot.LogMacros
  alias Nostrum.Api
  alias Nostrum.Struct.{Embed, Message, User}
  alias Scrybot.Discord.{Colors, Emoji}
  alias Scrybot.Discord.Command.CardInfo.{Card, Formatter, Parser}
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
  @spec do_command(Nostrum.Struct.Message.t()) :: :ok
  def do_command(%Message{author: %User{bot: bot}} = message) when bot in [false, nil] do
    debug("do_command")
    requests = Parser.tokenize(message.content, message)

    case requests do
      [] ->
        :ok

      _ ->
        for {mode, query, options} <- requests do
          mode
          |> case do
            :art ->
              query
              |> art(options, message)
              |> Stream.map(fn x -> {mode, Card.from_map(x.body)} end)
              |> Stream.map(fn x -> handle_maybe_ambiguous_art(x, query, message) end)

            :fuzzy ->
              with {:ok, info} <- fuzzy(query, options, message) do
                {:card, Card.from_map(info.body)}
              end

            :exact ->
              query
              |> exact(options, message)
              |> Stream.map(fn x -> {mode, Card.from_map(x.body)} end)
              |> Stream.map(fn x -> handle_maybe_ambiguous(x, query, message) end)

            # :edhrec ->
            #  edhrec(query, options, message)

            # :search ->
            #  search(query, options, message)

            :error ->
              case options do
                "ambiguous" -> ambiguous(query, message)
                _ -> send(Scrybot.Discord.FailureDispatcher, {:error, query, message})
              end
          end
        end
        |> Formatter.format()
        |> return(message)

        :ok
    end
  end

  defp fuzzy(card_name, options, ctx) do
    debug("fuzzy")
    debug(inspect(card_name))
    debug(inspect(options))
    debug(inspect(ctx))

    opts =
      for option <- options do
        case option do
          {"set", set} ->
            {:set, set}

          {name, _val} ->
            send(
              Scrybot.Discord.FailureDispatcher,
              {:warning, "Unknown option name '#{name}'", ctx}
            )

            :skip
        end
      end
      |> Enum.reject(fn x -> x == :skip end)

    t =
      card_name
      |> Scryfall.Api.cards_named(false, opts)

    debug("T " <> inspect(t))

    t
  end

  defp exact(card_name, options, ctx) do
    debug("exact")

    opts =
      for option <- options do
        case option do
          {"set", set} ->
            {:set, set}

          {name, _val} ->
            send(
              Scrybot.Discord.FailureDispatcher,
              {:warning, "Unknown option name '#{name}'", ctx}
            )

            :skip
        end
      end
      |> Enum.reject(fn x -> x == :skip end)

    card_name
    |> Scryfall.Api.cards_named(true, opts)
  end

  defp art(card_name, options, ctx) do
    debug("art")

    opts =
      for option <- options do
        case option do
          {"set", set} ->
            {:set, set}

          {"face", face} ->
            {:face, face}

          {name, _val} ->
            send(
              Scrybot.Discord.FailureDispatcher,
              {:warning, "Unknown option name '#{name}'", ctx}
            )

            :skip
        end
      end
      |> Enum.reject(fn x -> x == :skip end)

    card_name
    |> Scryfall.Api.cards_named(false, opts)
  end

  defp ambiguous(card_name, ctx) do
    debug("ambiguous")

    card_name
    |> Scryfall.Api.autocomplete()
    |> return_alternate_cards(card_name, ctx)
  end

  defp handle_card(card_info, ctx) do
    debug("handle_card")

    case card_info do
      {:ok, info} ->
        rulings =
          case Scryfall.Api.rulings(info.body["id"]) do
            {:ok, %{body: resp}} ->
              resp["data"]

            {:error, reason, _} ->
              send(
                Scrybot.Discord.FailureDispatcher,
                {:warn, reason, ctx}
              )

              []
          end

        {info, rulings}

      {:error, message, _} ->
        return_error(message, ctx)
    end
  end

  defp handle_art(card_info, card_name, ctx) do
    debug("handle_art")

    case card_info do
      {:ok, info} -> [{:art, dft_map(info, card_name)}]
      {:error, message, _} -> [{:error, message}]
    end
  end

  defp handle_maybe_ambiguous(card_info, card_name, ctx) do
    debug("handle_maybe_ambiguous")

    case card_info do
      {:error, _, "ambiguous"} -> ambiguous(card_name, ctx)
      _ -> handle_card(card_info, ctx)
    end
  end

  defp handle_maybe_ambiguous_art(card_info, card_name, ctx) do
    debug("handle_maybe_ambiguous_art")

    case card_info do
      {:error, _, "ambiguous"} -> ambiguous(card_name, ctx)
      _ -> handle_art(card_info, card_name, ctx)
    end
  end

  defp handle_search(search_term, options, ctx, :search) do
    debug("handle_search")

    opts =
      for option <- options do
        case option do
          {"unique", unique} when unique in ["cards", "art", "prints"] ->
            {:unique, unique}

          {"order", order}
          when order in [
                 "name",
                 "set",
                 "released",
                 "rarity",
                 "color",
                 "usd",
                 "tix",
                 "eur",
                 "cmc",
                 "power",
                 "toughness",
                 "edhrec",
                 "artist"
               ] ->
            {:order, order}

          {"dir", dir} when dir in ["auto", "asc", "desc"] ->
            {:dir, dir}

          {"include", "extras"} ->
            {:include_extras, true}

          {"include", "multilingual"} ->
            {:include_multilingual, true}

          {"include", "variations"} ->
            {:include_variations, true}

          {name, val} ->
            send(
              Scrybot.Discord.FailureDispatcher,
              {:warning, "Unknown option name/value '#{name}=#{val}'", ctx}
            )

            :skip
        end
      end
      |> Enum.reject(fn x -> x == :skip end)

    search_term
    |> Scryfall.Api.cards_search(opts)
    |> handle_search_results(ctx)
  end

  defp handle_search(search_term, options, ctx, :edhrec) do
    debug("handle_search 2")

    opts =
      for option <- options do
        case option do
          {"unique", unique} when unique in ["cards", "art", "prints"] ->
            {:unique, unique}

          {"order", order}
          when order in [
                 "name",
                 "set",
                 "released",
                 "rarity",
                 "color",
                 "usd",
                 "tix",
                 "eur",
                 "cmc",
                 "power",
                 "toughness",
                 "edhrec",
                 "artist"
               ] ->
            {:order, order}

          {"dir", dir} when dir in ["auto", "asc", "desc"] ->
            {:dir, dir}

          {"include", "extras"} ->
            {:include_extras, true}

          {"include", "multilingual"} ->
            {:include_multilingual, true}

          {"include", "variations"} ->
            {:include_variations, true}

          {name, val} ->
            send(
              Scrybot.Discord.FailureDispatcher,
              {:warning, "Unknown option name/value '#{name}=#{val}'", ctx}
            )

            :skip
        end
      end
      |> Enum.reject(fn x -> x == :skip end)

    search_term
    |> Scryfall.Api.cards_search(opts)
    |> handle_search_results(ctx, :edhrec)
  end

  defp handle_search_results(results, ctx, mode \\ :search)

  defp handle_search_results({:ok, results}, ctx, mode) do
    debug("handle_search_results")
    return_search_results(results, ctx, mode)
  end

  defp handle_search_results({:error, reason, _}, ctx, _mode) do
    debug("handle_search_results 2")

    send(
      Scrybot.Discord.FailureDispatcher,
      {:error, reason, ctx}
    )
  end

  defp return_card(%Card{layout: layout} = card, rulings, ctx)
       when layout in [:split, :flip, :transform, :double_faced_token] do
    debug("return_card")
    [last_face | faces] = card.card_faces |> Enum.reverse()

    for face <- faces |> Enum.reverse() do
      Map.merge(card, face)
    end
    |> Enum.each(fn x ->
      return_card(x, [], ctx)
    end)

    case last_face do
      nil ->
        :ok

      face ->
        return_card(Map.merge(card, face), rulings, ctx)
    end
  end

  defp return_card(info, rulings, ctx) do
    debug("return_card 2")

    embeds =
      case Formatter.fits_limits?(info, rulings) do
        true ->
          [
            %Embed{}
            |> Embed.put_title(Formatter.md_escape(info.name))
            |> Embed.put_url(info.scryfall_url)
            |> Embed.put_description(
              Emoji.emojify(info.mana_cost <> "\n" <> Formatter.card_description(info))
            )
            |> Formatter.legalities(info.legalities)
            |> Embed.put_thumbnail(info.image_uris.small)
            |> Formatter.rulings(rulings)
            |> Embed.put_footer(Formatter.footer(), @scryfall_icon_uri)
          ]

        false ->
          [
            %Embed{}
            |> Embed.put_title(Formatter.md_escape(info.name))
            |> Embed.put_url(info.scryfall_uri)
            |> Embed.put_description(
              Emoji.emojify(info.mana_cost <> "\n" <> Formatter.card_description(info))
            )
            |> Formatter.legalities(info.legalities)
            |> Embed.put_thumbnail(info.image_uris.normal),
            %Embed{}
            |> Formatter.rulings(rulings)
            |> Embed.put_footer(Formatter.footer(), @scryfall_icon_uri)
          ]
      end

    for embed <- embeds do
      Api.create_message(ctx.channel_id, embed: embed)
    end
  end

  defp dft_map(info = %Card{layout: "double_faced_token"}, card_name) do
    debug("dft_map")

    for face <- info.card_faces do
      if Scrybot.DamerauLevenshtein.equivalent?(
           face.name,
           card_name,
           Integer.floor_div(String.length(card_name), 4)
         ) do
        Map.merge(info, face)
      end
    end
    |> Enum.filter(fn
      nil -> false
      _ -> true
    end)
  end

  defp dft_map(info, _), do: info

  defp return([], ctx) do
    debug("return")

    send(
      Scrybot.Discord.FailureDispatcher,
      {:error, "The query resulted in no valid results. This is a bug.", ctx}
    )
  end

  defp return(embeds, ctx) when is_list(embeds) do
    debug("return 2")

    for embed <- embeds do
      Api.create_message(ctx.channel_id, embed: embed)
    end
  end

  defp return_alternate_cards({:error, message, _}, _, ctx), do: return_error(message, ctx)

  defp return_alternate_cards({:ok, resp}, card_name, ctx) do
    debug("return_alternate_cards")

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
    debug("return_search_results")

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
    debug("return_search_results 2")

    card_list =
      results["data"]
      |> Enum.to_list()
      |> Enum.map(fn x -> "- **#{x["name"]}** (##{x["edhrec_rank"]})" end)
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
    debug("return_error")
    Api.create_message(ctx.channel_id, embed: message)
  end
end
