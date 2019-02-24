defmodule Scrybot.Discord.Behaviour.ReactionHandler do
  @moduledoc false
  @callback do_reaction_command(mode :: :add | :remove, reaction :: map()) :: :ok
end
