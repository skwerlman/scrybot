defmodule Scrybot.Discord.Behaviour.Handler do
  @moduledoc false
  @callback init() :: :ok
  @callback allow_bots?() :: boolean()
end
