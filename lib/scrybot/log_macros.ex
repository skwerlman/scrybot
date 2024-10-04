defmodule Scrybot.LogMacros do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require Logger
      import Scrybot.LogMacros, only: [debug: 1, info: 1, warn: 1, error: 1]

      Module.put_attribute(
        __MODULE__,
        :logger_macro_logger_prefix___we_dont_want_name_collisions,
        ["[", inspect(__MODULE__), "] "]
      )
    end
  end

  defmacro debug(msg) do
    quote do
      _ =
        Logger.debug(fn ->
          [@logger_macro_logger_prefix___we_dont_want_name_collisions, unquote(msg)]
        end)
    end
  end

  defmacro info(msg) do
    quote do
      _ =
        Logger.info(fn ->
          [@logger_macro_logger_prefix___we_dont_want_name_collisions, unquote(msg)]
        end)
    end
  end

  defmacro warning(msg) do
    quote do
      _ =
        Logger.warning(fn ->
          [@logger_macro_logger_prefix___we_dont_want_name_collisions, unquote(msg)]
        end)
    end
  end

  defmacro warn(msg) do
    quote do
      _ =
        Logger.warning(fn ->
          [@logger_macro_logger_prefix___we_dont_want_name_collisions, unquote(msg)]
        end)
    end
  end

  defmacro error(msg) do
    quote do
      _ =
        Logger.error(fn ->
          [@logger_macro_logger_prefix___we_dont_want_name_collisions, unquote(msg)]
        end)
    end
  end
end
