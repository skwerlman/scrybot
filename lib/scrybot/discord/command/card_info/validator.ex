defmodule Scrybot.Discord.Command.CardInfo.Validator do
  @moduledoc false

  use Scrybot.LogMacros

  @doc """
  Applies a validation chain.
  """
  @spec validate((value -> boolean), value) :: boolean when value: var
  def validate(validator, value) do
    validator.(value)
  end

  @doc """
  Marks a validator chain as nilable.
  """
  @spec nilable((term -> boolean)) :: (term -> boolean)
  def nilable(validator) do
    fn
      value when is_nil(value) ->
        true

      value ->
        validator.(value)
    end
  end

  @doc """
  Accepts a validator, and returns a list validator.
  """
  @spec list_of((term -> boolean)) :: (term -> boolean)
  def list_of(validator) do
    fn
      list when is_list(list) ->
        Enum.reduce_while(
          list,
          true,
          fn i, _ ->
            valid = validator.(i)
            (valid && {:cont, true}) || {:halt, false}
          end
        )

      _ ->
        debug("WASNT A LIST")
        false
    end
  end

  @doc """
  Accepts a key validator and a value validator, and returns a map validator.
  """
  @spec map_of((key -> boolean), (val -> boolean)) :: (%{key => val} -> boolean) | (term -> false)
        when key: term, val: term
  def map_of(key_validator, val_validator) do
    fn
      map when is_map(map) ->
        map
        |> Map.to_list()
        |> Enum.reduce_while(
          true,
          fn {k, v}, _ ->
            valid = key_validator.(k) && val_validator.(v)
            (valid && {:cont, true}) || {:halt, false}
          end
        )

      _ ->
        false
    end
  end

  @doc """
  Accepts a list of validators, and returns a validator that matches if any in the list match.
  """
  @spec one_of([(term -> boolean)]) :: (term -> boolean)
  def one_of(validators) do
    fn value ->
      validators
      |> Enum.reduce_while(
        false,
        fn validator, _ ->
          valid = !validator.(value)
          (valid && {:cont, false}) || {:halt, true}
        end
      )
    end
  end

  @spec non_neg_integer() :: (term -> boolean)
  def non_neg_integer do
    fn
      value when is_integer(value) ->
        value >= 0

      _ ->
        false
    end
  end

  @spec uuid() :: (term -> boolean)
  def uuid do
    fn
      string when is_binary(string) ->
        case UUID.info(string) do
          {:error, _} -> false
          {:ok, uuid} -> Keyword.get(uuid, :type) == :default
        end

      _ ->
        false
    end
  end

  @spec printable() :: (term -> boolean)
  def printable do
    fn
      string when is_binary(string) ->
        String.printable?(string)

      _ ->
        false
    end
  end

  @spec uri() :: (term -> boolean)
  def uri do
    fn
      string when is_binary(string) ->
        uri = URI.parse(string)

        printable().(uri.host) && printable().(uri.path) &&
          printable().(uri.scheme)

      _ ->
        false
    end
  end

  @spec color() :: (term -> boolean)
  def color do
    fn
      string when is_binary(string) ->
        string in ["W", "U", "B", "R", "G"]

      _ ->
        false
    end
  end
end
