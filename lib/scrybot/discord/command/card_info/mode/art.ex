defmodule Scrybot.Discord.Command.CardInfo.Mode.Art do
  @moduledoc false
  use Scrybot.LogMacros
  alias Scrybot.Scryfall

  @spec art(binary, any, any) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
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
end
