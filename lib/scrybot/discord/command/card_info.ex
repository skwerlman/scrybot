defmodule Scrybot.Discord.Command.CardInfo do
  @moduledoc false
  use Scrybot.LogMacros
  alias LibJudge.Filter
  alias Nostrum.Api
  alias Nostrum.Struct.{Embed, Message, User}
  alias Scrybot.Discord.Command.CardInfo.{Card, Formatter, Parser}
  alias Scrybot.Scryfall

  @behaviour Scrybot.Discord.Behaviour.Handler
  @behaviour Scrybot.Discord.Behaviour.CommandHandler

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
          |> (fn
                {:error, _} ->
                  mode

                mode ->
                  with {:ok, info} <- apply(__MODULE__, mode, [query, options, message]),
                       mapped_mode <- mode_map(mode) do
                    case mapped_mode do
                      :list ->
                        {mapped_mode, {info.body, query: query}}

                      :rule ->
                        {mapped_mode, {info, query: query}}

                      _ ->
                        {mapped_mode, {Card.from_map(info.body), query: query}}
                    end
                  end
              end).()
          |> case do
            {:error, embed, options} ->
              debug("looking at an error here:")
              debug(inspect(embed))
              debug(inspect(options))

              case {options, embed} do
                {"ambiguous", _} ->
                  {:ok, resp} = Scryfall.Api.autocomplete(query)
                  {:ambiguous, {resp, query: query}}

                {_, %Embed{}} ->
                  {:error, embed}

                _ ->
                  send(
                    Scrybot.Discord.FailureDispatcher,
                    {:error, "The query #{inspect(query)} produced an error!", message}
                  )
              end

            {:error, {_kind, _info} = t} ->
              send(
                Scrybot.Discord.FailureDispatcher,
                {:error, "The query #{inspect(query)} produced an error!\n`#{inspect(t)}`",
                 message}
              )

            card ->
              card
          end
        end
        |> Formatter.format()
        |> return(message)

        :ok
    end
  end

  @spec fuzzy(binary, any, any) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  def fuzzy(card_name, options, ctx) do
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

  @spec exact(binary, any, any) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  def exact(card_name, options, ctx) do
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

  @spec art(binary, any, any) :: {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  def art(card_name, options, ctx) do
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

  @spec search(binary, keyword({binary, any}), Nostrum.Struct.Message.t()) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  def search(search_term, options, ctx) do
    debug("search")

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
  end

  @spec rule(binary, any, any) :: {:ok, [LibJudge.Tokenizer.rule()]}
  def rule(query, _options, _ctx) do
    error("HERE")
    rules = Application.get_env(:scrybot, :rules, [])

    filter =
      Filter.either(
        Filter.rule_is(query),
        Filter.body_contains(query)
      )

    matches =
      rules
      |> Enum.filter(filter)

    {:ok, matches}
  end

  defp mode_map(mode) do
    case mode do
      :fuzzy -> :card
      :exact -> :card
      :edhrec -> :list
      :search -> :list
      _ -> mode
    end
  end

  defp return([], ctx) do
    send(
      Scrybot.Discord.FailureDispatcher,
      {:error,
       "The query resulted in no valid results.\nThis is because of:\n- the errors above (if any)\n- a bug",
       ctx}
    )
  end

  defp return(embeds, ctx) when is_list(embeds) do
    for embed <- embeds do
      Api.create_message(ctx.channel_id, embed: embed)
    end
  end
end
