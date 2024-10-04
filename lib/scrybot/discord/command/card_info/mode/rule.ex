defmodule Scrybot.Discord.Command.CardInfo.Mode.Rule do
  @moduledoc false
  use Scrybot.LogMacros
  alias LibJudge.Filter

  @spec rule(binary, keyword({binary, any}), Nostrum.Struct.Message.t()) ::
          {:ok, [LibJudge.Tokenizer.rule()]}
  def rule(query, options, ctx) do
    rules = Application.get_env(:scrybot, :rules, [])

    opts =
      for option <- options do
        case option do
          {"max", max} when is_binary(max) ->
            {maxn, _} = Integer.parse(max)
            {:max, maxn}

          {"max", max} when is_integer(max) ->
            {:max, max}

          {name, val} ->
            send(
              Scrybot.Discord.FailureDispatcher,
              {:warning, "Unknown option name/value '#{name}=#{val}'", ctx}
            )

            :skip
        end
      end
      |> Enum.reject(fn x -> x == :skip end)

    filter =
      Filter.any([
        Filter.rule_is(query),
        Filter.rule_starts_with(query),
        body_contains_insensitive(query)
      ])

    all_matches =
      rules
      |> Enum.filter(filter)

    limit = Keyword.get(opts, :max, 10)
    count = length(all_matches)

    matches =
      if count > limit do
        send(
          Scrybot.Discord.FailureDispatcher,
          {:success, "Showing #{limit} of #{count} results", ctx}
        )

        all_matches
        |> Enum.take(limit)
      else
        all_matches
      end

    {:ok, matches}
  end

  defp body_contains_insensitive(text) do
    fn
      {:rule, {_type, _rule, body, _examples}} when is_binary(body) ->
        String.contains?(
          String.downcase(body),
          String.downcase(text)
        )

      _ ->
        false
    end
  end
end
