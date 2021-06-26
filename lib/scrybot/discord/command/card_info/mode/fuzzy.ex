defmodule Scrybot.Discord.Command.CardInfo.Mode.Fuzzy do
  @moduledoc false
  use Scrybot.LogMacros
  alias Scrybot.Scryfall

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
end
