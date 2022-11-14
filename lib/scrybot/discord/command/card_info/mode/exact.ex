defmodule Scrybot.Discord.Command.CardInfo.Mode.Exact do
  @moduledoc false
  use Scrybot.LogMacros
  alias Scrybot.Scryfall

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
end
