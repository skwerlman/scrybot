defmodule Scrybot.Discord.Command.CardInfo.Card.Face do
  @moduledoc false
  alias Scrybot.Discord.Command.CardInfo.Card
  import Scrybot.Discord.Command.CardInfo.Validator
  use Scrybot.LogMacros

  @type t :: %__MODULE__{
          artist: String.t() | nil,
          color_indicator: [String.t() | nil],
          colors: [String.t() | nil],
          flavor_text: String.t() | nil,
          illustration_id: String.t() | nil,
          image_uris: %{String.t() => String.t()} | nil,
          loyalty: String.t() | nil,
          mana_cost: String.t() | nil,
          name: String.t(),
          object: String.t(),
          oracle_text: String.t() | nil,
          power: String.t() | nil,
          printed_name: String.t() | nil,
          printed_type_line: String.t() | nil,
          toughness: String.t() | nil,
          type_line: String.t(),
          watermark: String.t() | nil
        }

  @enforce_keys [
    :mana_cost,
    :name,
    :object,
    :type_line
  ]

  defstruct [
    :artist,
    :color_indicator,
    :colors,
    :flavor_text,
    :illustration_id,
    :image_uris,
    :loyalty,
    :mana_cost,
    :name,
    :object,
    :oracle_text,
    :power,
    :printed_name,
    :printed_type_line,
    :toughness,
    :type_line,
    :watermark
  ]

  @spec from_map(map) :: __MODULE__.t()
  def from_map(card), do: Card.from_map(__MODULE__, card)

  @spec valid?(__MODULE__.t()) :: boolean
  def valid?(face) do
    debug("validating face #{inspect(face.name)}")

    {_, valid} =
      face
      |> Map.to_list()
      |> Enum.map_reduce(true, fn {k, v}, acc -> {v, acc && valid?(k, v)} end)

    debug("done face")

    valid
  end

  # see comment for Card.valid?
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp valid?(key, value) do
    debug("checking key #{inspect(key)}")

    case key do
      :artist ->
        printable()
        |> nilable()
        |> validate(value)

      :color_indicator ->
        color()
        |> list_of()
        |> nilable()
        |> validate(value)

      :colors ->
        color()
        |> list_of()
        |> nilable()
        |> validate(value)

      :flavor_text ->
        printable()
        |> nilable()
        |> validate(value)

      :illustration_id ->
        uuid()
        |> nilable()
        |> validate(value)

      :image_uris ->
        printable()
        |> map_of(uri())
        |> nilable()
        |> validate(value)

      :loyalty ->
        printable()
        |> nilable()
        |> validate(value)

      :mana_cost ->
        printable()
        |> nilable()
        |> validate(value)

      :name ->
        printable().(value)

      :object ->
        value == "card_face"

      :oracle_text ->
        printable()
        |> nilable()
        |> validate(value)

      :power ->
        printable()
        |> nilable()
        |> validate(value)

      :printed_name ->
        printable()
        |> nilable()
        |> validate(value)

      :printed_type_line ->
        printable()
        |> nilable()
        |> validate(value)

      :toughness ->
        printable()
        |> nilable()
        |> validate(value)

      :type_line ->
        printable().(value)

      :watermark ->
        printable()
        |> nilable()
        |> validate(value)

      :__struct__ ->
        value == __MODULE__
    end
  end
end
