defmodule Scrybot.LogMacros do
  @moduledoc false
  require Logger

  defmacro debug(msg) do
    quote do
      _ = Logger.debug(fn -> unquote(msg) end)
      :ok
    end
  end

  defmacro info(msg) do
    quote do
      _ = Logger.info(fn -> unquote(msg) end)
      :ok
    end
  end

  defmacro warn(msg) do
    quote do
      _ = Logger.warn(fn -> unquote(msg) end)
      :ok
    end
  end

  defmacro error(msg) do
    quote do
      _ = Logger.error(fn -> unquote(msg) end)
      :ok
    end
  end
end
