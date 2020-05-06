defmodule Scrybot.Discord.Colors do
  @moduledoc """
  A collection of nice status colors to be applied to discord embeds.
  """

  @spec error :: 0xE74C3C
  def error do
    0xE74C3C
  end

  @spec warning :: 0xFFE74C
  def warning do
    0xFFE74C
  end

  @spec success :: 0x6BF178
  def success do
    0x6BF178
  end

  @spec info :: 0x35A7FF
  def info do
    0x35A7FF
  end

  @spec from_atom(:error | :info | :success | :warning) :: integer
  def from_atom(atom) when atom in [:error, :warning, :success, :info] do
    apply(__MODULE__, atom, [])
  end
end
