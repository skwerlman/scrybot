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
        # let the user know we're thinking if its taking a while
        {:ok, timer_proc} = Task.start(type_after(300, message))

        results =
          requests
          |> Stream.map(&do_request(&1, message))
          |> Formatter.format()
          |> Enum.map(fn x ->
            # cancel the typing timer if its still around
            # cancelling is idempotent so its fine to do it in a map :)
            _ = Process.send(timer_proc, :cancel, [])
            return(x, message)
          end)

        if results == [] do
          send(
            Scrybot.Discord.FailureDispatcher,
            {:error,
             "The query resulted in no valid results.\nThis is because of:\n- the errors above (if any)\n- a bug",
             message}
          )
        end

        :ok
    end
  end

  defp mode_map(mode) do
    case mode do
      :fuzzy -> :card
      :exact -> :card
      :edhrec -> :list
      :search -> :list
      :price -> :list
      _ -> mode
    end
  end

  defp do_request(request = {mode, query, options}, message) do
    debug("request: #{inspect(request)}")

    mode
    |> apply_request_mode(query, options, message)
    |> handle_errors(query, message)
  end

  defp handle_errors({:error, _, "ambiguous"}, query, _) do
    {:ok, resp} = Scryfall.Api.autocomplete(query)
    {:ambiguous, {resp, query: query}}
  end

  defp handle_errors({:error, embed = %Embed{}, _}, _, _) do
    {:error, embed}
  end

  defp handle_errors({:error, _, _}, query, message) do
    send(
      Scrybot.Discord.FailureDispatcher,
      {:error, "The query #{inspect(query)} produced an error!", message}
    )
  end

  defp handle_errors({:error, t = {_, _}}, query, message) do
    send(
      Scrybot.Discord.FailureDispatcher,
      {:error, "The query #{inspect(query)} produced an error!\n`#{inspect(t)}`", message}
    )
  end

  defp handle_errors(card, _, _), do: card

  defp apply_request_mode(mode = {:error, _}, _query, _options, _message) do
    mode
  end

  defp apply_request_mode(mode, query, options, message) do
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

  defp return(embed, ctx) do
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

      {:error, %{status_code: 429}} ->
        # if the discord ratelimiter breaks (again), do it ourselves
        # we already have a pending typing timer, no need to start here

        # sleep for 3s (dialyzer thinks the ratelimit match was broken)
        # this isnt bulletproof; simultaneous requests break this
        # but we're only ever here if ratelimiting is already broken
        Process.sleep(3000)
        return([embed], ctx)

      err ->
        error(inspect(err))

        send(
          Scrybot.Discord.FailureDispatcher,
          {:error, "An embed failed to send. This is a bug.", ctx}
        )
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
      after
        delay ->
          _ = Api.start_typing(ctx.channel_id)
      end
    end
  end
end
