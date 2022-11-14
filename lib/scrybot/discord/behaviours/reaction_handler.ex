defmodule Scrybot.Discord.Behaviour.ReactionHandler do
  @moduledoc false
  @type mode() :: :add | :remove
  @callback do_reaction_command(mode(), reaction :: map()) :: :ok
end
