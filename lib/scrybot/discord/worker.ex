defmodule Scrybot.Discord.Worker do
  @moduledoc false
  alias Scrybot.Discord.Command
  use Nostrum.Consumer
  require Logger

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:MESSAGE_CREATE, {message}, _ws}) do
    command_handlers = Command.handlers()

    command_handlers
    |> Enum.each(&Command.do_command(&1, message))

    :ok
  end

  def handle_event(_), do: :noop
end
