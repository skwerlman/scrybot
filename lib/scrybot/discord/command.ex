defmodule Scrybot.Discord.Command do
  @moduledoc false
  require Logger

  def handlers do
    Application.get_env(
      :scrybot,
      :command_handlers,
      [Scrybot.Discord.Command.CardInfo, Scrybot.Discord.Command.Core]
    )
  end

  defp init_once(module) do
    # Task.start(fn ->
    try do
      module.init()
    rescue
      FunctionClauseError -> :ignore
      e -> Logger.error(inspect(e))
    end

    # end)
  end

  def do_command(module, message) do
    # Task.start(fn ->
      try do
        case message do
          m = %{bot: true} ->
            module.allow_bots?() && module.do_command(m)

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

    # end)
          Logger.error(Exception.format(:error, e, :erlang.get_stacktrace()))
      end
  end

  def init do
    handlers()
    |> Enum.each(&init_once(&1))
  end
end
