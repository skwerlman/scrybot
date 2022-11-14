defmodule Scrybot.Discord.Command.CardInfo.Mode.Search do
  @moduledoc false
  use Scrybot.LogMacros
  alias Scrybot.Scryfall

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
end
