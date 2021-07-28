defmodule ScrybotTest do
  @moduledoc false
  use ExUnit.Case

  alias Scrybot.Discord.Command.CardInfo.Parser

  doctest Scrybot

  test "tokenizer works" do
    msg =
      "hi hello \n[[force of \nwill]]whee[a[doot]someopt=3] [7[foobar]] [À[multibyte grapheme]] [e[invalid opts]test=ok,broken] [invalid[ohno]][[a[test card]]garbage text"

    tokens = [
      {:fuzzy, "force of \nwill", []},
      {:art, "doot",
       [
         {"someopt", "3"}
       ]},
      {{:error, {:bad_mode, "7"}}, "foobar", []},
      {{:error, {:bad_mode, "À"}}, "multibyte grapheme", []},
      {:edhrec, "invalid opts", [{"test", "ok"}]},
      {:fuzzy, "a[test card", []}
    ]

    assert Parser.tokenize(msg, :NONE) == tokens
  end
end
