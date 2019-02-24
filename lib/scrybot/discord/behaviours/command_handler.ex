defmodule Scrybot.Discord.Behaviour.CommandHandler do
  @moduledoc false
  @callback do_command(message :: %Nostrum.Struct.Message{}) :: :ok
end
