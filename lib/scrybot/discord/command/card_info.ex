defmodule Scrybot.Discord.Command.CardInfo do
  @moduledoc false
  use Scrybot.LogMacros
  alias Nostrum.Api
  alias Nostrum.Struct.{Embed, Message, User}
  alias Scrybot.Discord.Command.CardInfo.{Card, Formatter, Mode, Parser}
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
    requests = Parser.tokenize(message.content, message)

    case requests do
      [] ->
        # no requests, so nothing to do
        :ok

      _ ->
        # let the user know we're thinking
        _ = Api.start_typing(message.channel_id)

        for request = {mode, query, options} <- requests do
          debug("request: #{inspect(request)}")

          mode
          |> case do
            {:error, _} ->
              mode

            mode ->
              with {:ok, info} <- apply(Mode, mode, [query, options, message]),
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
          end
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
      # create a task to start typing if we get rate limited
      # we use a task with a delay instead of always sending
      # so that the indicator doesnt flicker
      {:ok, timer_proc} = Task.start(type_after(300, ctx))
      # try to send the message
      res = Api.create_message(ctx.channel_id, embed: embed)

      case res do
        {:ok, _} ->
          # message is sent, so we cancel the pending typing indicator
          _ = Process.send(timer_proc, :cancel, [])
          :ok

        {:error, %{response: %{retry_after: wait}, status_code: 429}} ->
          # if the discord ratelimiter breaks (again), do it ourselves
          # we already have a pending typing timer, no need to start here

          # sleep for however long discord wants us to
          # this isnt bulletproof; simultaneous requests break this
          # but we're only ever here if ratelimiting is already broken
          Process.sleep(wait)
          return([embed], ctx)

        err ->
          error(inspect(err))

          send(
            Scrybot.Discord.FailureDispatcher,
            {:error, "An embed failed to send. This is a bug.", ctx}
          )
      end
    end
  end

  defp type_after(delay, ctx) do
    # return a function for Task.start that is cancellable
    # if the recieve times out, we start typing. otherwise, nothing
    # We dont care if this gets killed brutally during shutdown, so
    # no need for a Task.Supervisor above this
    fn ->
      receive do
        :cancel ->
          :ok
      after delay ->
        _ = Api.start_typing(ctx.channel_id)
      end
    end
  end
end
