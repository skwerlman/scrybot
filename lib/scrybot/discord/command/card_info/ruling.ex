defmodule Scrybot.Discord.Command.CardInfo.Ruling do
  @moduledoc false
  use Scrybot.LogMacros
  import Scrybot.Discord.Command.CardInfo.Validator

  @type t :: %__MODULE__{
          comment: String.t(),
          published_at: String.t(),
          object: String.t(),
          oracle_id: String.t(),
          source: String.t()
        }

  @enforce_keys [:comment, :object, :published_at, :source]

  defstruct [
    :comment,
    :published_at,
    :object,
    :oracle_id,
    :source
  ]

  @spec valid?(__MODULE__.t()) :: boolean
  def valid?(ruling) do
    debug("validating ruling #{inspect(ruling.published_at)}")

    {_, valid} =
      ruling
      |> Map.to_list()
      |> Enum.map_reduce(true, fn {k, v}, acc -> {v, acc && valid?(k, v)} end)

    debug("done")

    valid
  end

  defp valid?(key, value) do
    debug("checking key #{inspect(key)}")

    case key do
      :comment ->
        printable().(value)

      :object ->
        value == "ruling"

      :oracle_id ->
        uuid().(value)

      :published_at ->
        printable().(value)

      :source ->
        value in ["wotc", "scryfall"]
    end
  end
end
