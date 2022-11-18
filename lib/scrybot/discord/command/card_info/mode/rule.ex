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
          {"max", max} ->
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

    matches =
      all_matches
      |> Enum.take(Keyword.get(opts, :max, 10))

    if matches != all_matches do
      send(
        Scrybot.Discord.FailureDispatcher,
        {:success, "Showing #{length(matches)} of #{length(all_matches)} results", ctx}
      )
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
