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
        for request = {mode, query, options} <- requests do
          debug("request: #{inspect(request)}")

          mode
          |> case do
            :art ->
              with {:ok, info} <- art(query, options, message) do
                {:art, {Card.from_map(info.body), query: query}}
              end

            :fuzzy ->
              with {:ok, info} <- fuzzy(query, options, message) do
                {:card, {Card.from_map(info.body), query: query}}
              end

            :exact ->
              with {:ok, info} <- exact(query, options, message) do
                {:card, {Card.from_map(info.body), query: query}}
              end

              # :edhrec ->
              #   with {:ok, info} <- edhrec(query, options, message) do
              #     {:list, Card.from_map(info.body)}
              #   end

              # :search ->
              #   with {:ok, info} <- search(query, options, message) do
              #     {:list, Card.from_map(info.body)}
              #   end
          end
          |> case do
            {:error, _embed, options} ->
              case options do
                "ambiguous" ->
                  {:ok, resp} = Scryfall.Api.autocomplete(query)
                  {:ambiguous, {resp, query: query}}

                _ ->
                  send(Scrybot.Discord.FailureDispatcher, {:error, query, message})
                  # {:error, embed}
              end

            card ->
              card
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

  # defp handle_search(search_term, options, ctx, :search) do
  #   debug("handle_search")

  #   opts =
  #     for option <- options do
  #       case option do
  #         {"unique", unique} when unique in ["cards", "art", "prints"] ->
  #           {:unique, unique}

  #         {"order", order}
  #         when order in [
  #                "name",
  #                "set",
  #                "released",
  #                "rarity",
  #                "color",
  #                "usd",
  #                "tix",
  #                "eur",
  #                "cmc",
  #                "power",
  #                "toughness",
  #                "edhrec",
  #                "artist"
  #              ] ->
  #           {:order, order}

  #         {"dir", dir} when dir in ["auto", "asc", "desc"] ->
  #           {:dir, dir}

  #         {"include", "extras"} ->
  #           {:include_extras, true}

  #         {"include", "multilingual"} ->
  #           {:include_multilingual, true}

  #         {"include", "variations"} ->
  #           {:include_variations, true}

  #         {name, val} ->
  #           send(
  #             Scrybot.Discord.FailureDispatcher,
  #             {:warning, "Unknown option name/value '#{name}=#{val}'", ctx}
  #           )

  #           :skip
  #       end
  #     end
  #     |> Enum.reject(fn x -> x == :skip end)

  #   search_term
  #   |> Scryfall.Api.cards_search(opts)
  #   |> handle_search_results(ctx)
  # end

  # defp handle_search(search_term, options, ctx, :edhrec) do
  #   debug("handle_search 2")

  #   opts =
  #     for option <- options do
  #       case option do
  #         {"unique", unique} when unique in ["cards", "art", "prints"] ->
  #           {:unique, unique}

  #         {"order", order}
  #         when order in [
  #                "name",
  #                "set",
  #                "released",
  #                "rarity",
  #                "color",
  #                "usd",
  #                "tix",
  #                "eur",
  #                "cmc",
  #                "power",
  #                "toughness",
  #                "edhrec",
  #                "artist"
  #              ] ->
  #           {:order, order}

  #         {"dir", dir} when dir in ["auto", "asc", "desc"] ->
  #           {:dir, dir}

  #         {"include", "extras"} ->
  #           {:include_extras, true}

  #         {"include", "multilingual"} ->
  #           {:include_multilingual, true}

  #         {"include", "variations"} ->
  #           {:include_variations, true}

  #         {name, val} ->
  #           send(
  #             Scrybot.Discord.FailureDispatcher,
  #             {:warning, "Unknown option name/value '#{name}=#{val}'", ctx}
  #           )

  #           :skip
  #       end
  #     end
  #     |> Enum.reject(fn x -> x == :skip end)

  #   search_term
  #   |> Scryfall.Api.cards_search(opts)
  #   |> handle_search_results(ctx, :edhrec)
  # end

  # defp return_search_results(%{body: results}, ctx, :search) do
  #   # debug(inspect(results))
  #   debug("return_search_results")

  #   card_list =
  #     results["data"]
  #     |> Enum.to_list()
  #     |> Enum.map(fn x -> "- #{x["name"]}" end)
  #     |> Enum.take(50)

  #   msg_body =
  #     card_list
  #     |> Enum.join("\n")

  #   embed =
  #     %Embed{}
  #     |> Embed.put_color(Colors.info())
  #     |> Embed.put_title("Search Results (#{length(card_list)} of #{results["total_cards"]})")
  #     |> Embed.put_description("#{msg_body}")

  #   Api.create_message(ctx.channel_id, embed: embed)
  # end

  # defp return_search_results(%{body: results}, ctx, :edhrec) do
  #   # debug(inspect(results))
  #   debug("return_search_results 2")

  #   card_list =
  #     results["data"]
  #     |> Enum.to_list()
  #     |> Enum.map(fn x -> "- **#{x["name"]}** (##{x["edhrec_rank"]})" end)
  #     |> Enum.take(50)

  #   msg_body =
  #     card_list
  #     |> Enum.join("\n")

  #   embed =
  #     %Embed{}
  #     |> Embed.put_color(Colors.info())
  #     |> Embed.put_title(
  #       "EDHREC Search Results (#{length(card_list)} of #{results["total_cards"]})"
  #     )
  #     |> Embed.put_description("#{msg_body}")

  #   Api.create_message(ctx.channel_id, embed: embed)
  # end

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
end
