defmodule Scrybot.LogMacros do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      require Logger
      import Scrybot.LogMacros, only: [debug: 1, info: 1, warn: 1, error: 1]
    end
  end

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
