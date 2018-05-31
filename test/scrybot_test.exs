defmodule ScrybotTest do
  use ExUnit.Case
  doctest Scrybot

  test "greets the world" do
    assert Scrybot.hello() == :world
  end
end
