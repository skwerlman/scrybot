defmodule Scrybot.Discord.Command.CardInfo.Mode do
  @moduledoc false
  alias __MODULE__

  @spec exact(binary, any, any) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  defdelegate exact(card_name, options, ctx), to: Mode.Exact

  @spec fuzzy(binary, any, any) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  defdelegate fuzzy(card_name, options, ctx), to: Mode.Fuzzy

  @spec art(binary, any, any) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  defdelegate art(card_name, options, ctx), to: Mode.Art

  @spec search(binary, keyword({binary, any}), Nostrum.Struct.Message.t()) ::
          {:ok, Tesla.Env.t()} | {:error, Nostrum.Struct.Embed.t(), binary}
  defdelegate search(card_name, options, ctx), to: Mode.Search

  @spec rule(binary, keyword({binary, any}), Nostrum.Struct.Message.t()) ::
          {:ok, [LibJudge.Tokenizer.rule()]}
  defdelegate rule(card_name, options, ctx), to: Mode.Rule
end
