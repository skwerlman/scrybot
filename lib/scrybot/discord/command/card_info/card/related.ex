defmodule Scrybot.Discord.Command.CardInfo.Card.Related do
  @moduledoc false
  alias Scrybot.Discord.Command.CardInfo.Card
  import Scrybot.Discord.Command.CardInfo.Validator
  use Scrybot.LogMacros

  @type t :: %__MODULE__{
          id: String.t(),
          object: String.t(),
          component: String.t(),
          name: String.t(),
          type_line: String.t(),
          uri: String.t()
        }

  @enforce_keys [
    :id,
    :object,
    :component,
    :name,
    :type_line,
    :uri
  ]

  defstruct [
    :id,
    :object,
    :component,
    :name,
    :type_line,
    :uri
  ]

  @spec from_map(map) :: __MODULE__.t()
  def from_map(card), do: Card.from_map(__MODULE__, card)

  @spec valid?(__MODULE__.t()) :: boolean
  def valid?(related) do
    debug("validating related #{inspect(related.name)}")

    {_, valid} =
      related
      |> Map.to_list()
      |> Enum.map_reduce(true, fn {k, v}, acc -> {v, acc && valid?(k, v)} end)

    debug("done related")

    valid
  end

  defp valid?(key, value) do
    debug("checking key #{inspect(key)}")

    case key do
      :id -> uuid().(value)
      :object -> value == "related_card"
      :component -> value in ["token", "meld_part", "meld_result", "combo_piece"]
      :name -> printable().(value)
      :type_line -> printable().(value)
      :uri -> uri().(value)
      :__struct__ -> value == __MODULE__
    end
  end
end
