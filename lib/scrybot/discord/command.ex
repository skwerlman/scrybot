defmodule Scrybot.Discord.Command do
  @moduledoc false
  require Logger
  import Scrybot.LogMacros

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
          warn("Failed to initialize command module: #{inspect(module)}")
          warn(Exception.format(:error, e, __STACKTRACE__))
      end
    end)
  end

  def do_command(module, message) do
    _ =
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
            errmsg =
              case message do
                %Nostrum.Struct.Message{} ->
                  "Command execution failed for: #{inspect(message.content)}"

                _ ->
                  "Command execution failed for: #{inspect(message)}"
              end

            trace = Exception.format(:error, e, __STACKTRACE__)

            error(errmsg)
            error(trace)

            Nostrum.Api.create_message(message.channel_id, """
            :bomb: Sorry, an internal error occurred.

            `#{inspect(e)}`

            **Details:**
            ```
            #{trace}
            ```
            """)
        end
      end)

    :ok
  end

  def do_reaction_command(module, mode, reaction) do
    _ =
      Task.start(fn ->
        try do
          module.do_reaction_command(mode, reaction)
        rescue
          e ->
            error("Command execution failed for: #{inspect(mode)} #{inspect(reaction)}")

            error(Exception.format(:error, e, __STACKTRACE__))
        end
      end)

    :ok
  end

  def init do
    [handlers(), react_handlers()]
    |> Stream.concat()
    |> Stream.uniq()
    |> Enum.each(&init_once(&1))
  end
end
