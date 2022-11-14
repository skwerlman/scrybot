defmodule Scrybot.Discord.Command.CardInfo.Mode do
  @moduledoc false
  alias __MODULE__

  # convenience types
  @typep opt :: keyword({binary, any})
  @typep ok :: {:ok, Tesla.Env.t()}
  @typep err :: {:error, Nostrum.Struct.Embed.t(), binary}

  @spec exact(binary, opt, Nostrum.Struct.Message.t()) :: ok | err
  defdelegate exact(card_name, options, ctx), to: Mode.Exact

  @spec fuzzy(binary, opt, Nostrum.Struct.Message.t()) :: ok | err
  defdelegate fuzzy(card_name, options, ctx), to: Mode.Fuzzy

  @spec art(binary, opt, Nostrum.Struct.Message.t()) :: ok | err
  defdelegate art(card_name, options, ctx), to: Mode.Art

  @spec search(binary, opt, Nostrum.Struct.Message.t()) :: ok | err
  defdelegate search(card_name, options, ctx), to: Mode.Search

  @spec rule(binary, opt, Nostrum.Struct.Message.t()) ::
          {:ok, [LibJudge.Tokenizer.rule()]}
  defdelegate rule(card_name, options, ctx), to: Mode.Rule
end
