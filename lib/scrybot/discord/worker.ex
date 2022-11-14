defmodule Scrybot.Discord.Worker do
  @moduledoc false
  alias Nostrum.Consumer
  alias Scrybot.Discord.Command
  use Nostrum.Consumer

  # @spec start_link() :: Supervisor.on_start() | no_return()
  @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  def start_link do
    Consumer.start_link(__MODULE__)
  end

  @impl Nostrum.Consumer
  def handle_event({:MESSAGE_CREATE, message, _ws}) do
    command_handlers = Command.handlers()

    command_handlers
    |> Enum.each(&Command.do_command(&1, message))

    :ok
  end

  @impl Nostrum.Consumer
  def handle_event({:MESSAGE_REACTION_ADD, reaction, _ws}) do
    react_handlers = Command.react_handlers()

    react_handlers
    |> Enum.each(&Command.do_reaction_command(&1, :add, reaction))

    :ok
  end

  @impl Nostrum.Consumer
  def handle_event({:MESSAGE_REACTION_REMOVE, reaction, _ws}) do
    react_handlers = Command.react_handlers()

    react_handlers
    |> Enum.each(&Command.do_reaction_command(&1, :remove, reaction))

    :ok
  end

  @impl Nostrum.Consumer
  def handle_event(_), do: :ok
end
