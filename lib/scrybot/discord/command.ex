defmodule Scrybot.Discord.Command do
  @moduledoc false
  require Logger

  def handlers do
    Application.get_env(
      :scrybot,
      :command_handlers,
      [
        Scrybot.Discord.Command.CardInfo,
        Scrybot.Discord.Command.Core
      ]
    )
  end

  def react_handlers do
    Application.get_env(
      :scrybot,
      :react_handlers,
      [
        Scrybot.Discord.Command.Turtler3000
      ]
    )
  end

  defp init_once(module) do
    Task.start(fn ->
      try do
        module.init()
      rescue
        e ->
          Logger.warn("Failed to initialize command module: #{inspect(module)}")
          Logger.warn(Exception.format(:error, e, __STACKTRACE__))
      end
    end)
  end

  def do_command(module, message) do
    Task.start(fn ->
      try do
        case message do
          m = %{author: %{bot: true}} ->
            if module.allow_bots?() do
              module.do_command(m)
            end

          m ->
            module.do_command(m)
        end
      rescue
        e ->
          case message do
            %Nostrum.Struct.Message{} ->
              Logger.error("Command execution failed for: #{inspect(message.content)}")

            _ ->
              Logger.error("Command execution failed for: #{inspect(message)}")
          end

          Logger.error(Exception.format(:error, e, __STACKTRACE__))
      end
    end)
  end

  def do_reaction_command(module, mode, reaction) do
    Task.start(fn ->
      try do
        module.do_reaction_command(mode, reaction)
      rescue
        e ->
          Logger.error("Command execution failed for: #{inspect(mode)} #{inspect(reaction)}")

          Logger.error(Exception.format(:error, e, __STACKTRACE__))
      end
    end)
  end

  def init do
    [handlers(), react_handlers()]
    |> Stream.concat()
    |> Stream.uniq()
    |> Enum.each(&init_once(&1))
  end
end
