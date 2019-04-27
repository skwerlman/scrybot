defmodule Scrybot.Discord.Command.CardInfo.Parser do
  @moduledoc false

  alias Scrybot.Discord.FailureDispatcher

  @type opt :: {String.t(), String.t()}
  @type lookup_type :: :fuzzy | :exact | :art | :search | :edhrec
  @type lookup_tuple :: {
          lookup_type(),
          query :: String.t(),
          opts :: [opt()]
        }
  @type error_tuple :: {
          {:error, reason :: atom()},
          query :: String.t(),
          opts :: [opt()]
        }

  @spec parse(String.t(), term()) :: [lookup_tuple() | error_tuple()]
  def parse(text, ctx) do
    tokenize(text, ctx)
  end

  @spec tokenize(String.t(), term()) :: list()
  # return an empty list when no text found; end of recursion
  def tokenize("", _ctx), do: []

  # handle default (fuzzy) searches
  def tokenize("[[" <> term_and_rest, ctx) do
    case term_and_rest |> String.split("]", parts: 3) do
      [term, opts, rest] ->
        [{:fuzzy, term, tokenize_opts(opts, ctx)}] ++ tokenize(rest, ctx)

      _ ->
        send(
          FailureDispatcher,
          {:warning, "Unmatched `[`! Some searches will be incorrect or skipped.", ctx}
        )

        []
    end
  end

  # handle moded searches
  def tokenize("[" <> <<mode_string::bytes-size(1)>> <> "[" <> term_and_rest, ctx) do
    case term_and_rest |> String.split("]", parts: 3) do
      [term, opts, rest] ->
        [{mode(mode_string, ctx), term, tokenize_opts(opts, ctx)}] ++ tokenize(rest, ctx)

      _ ->
        send(
          FailureDispatcher,
          {:warning, "Unmatched `[`. Some searches will be incorrect or skipped.", ctx}
        )

        []
    end
  end

  # discard unrecognized bytes
  def tokenize(<<_garbage::bytes-size(1)>> <> rest, ctx), do: tokenize(rest, ctx)

  @spec tokenize_opts(String.t(), term()) :: [opt()]
  def tokenize_opts("", _ctx), do: []

  def tokenize_opts(opts, ctx) do
    opts
    |> String.split(",")
    |> Enum.map(fn x -> String.split(x, "=", parts: 2) end)
    |> Enum.filter(fn x ->
      case x do
        [_, _] ->
          true

        bad ->
          send(FailureDispatcher, {:warning, "Invalid option: #{bad}", ctx})
          false
      end
    end)
    |> Enum.map(fn [x, y] -> {x, y} end)
  end

  defp mode("a", _ctx), do: :art
  defp mode("e", _ctx), do: :edhrec
  defp mode("=", _ctx), do: :exact
  defp mode("?", _ctx), do: :search

  defp mode(mode, ctx) do
    send(FailureDispatcher, {:warning, "Invalid mode: #{mode}", ctx})
    {:error, :bad_mode}
  end
end
