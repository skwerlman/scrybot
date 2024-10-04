defmodule Scrybot.Discord.Command do
  @moduledoc false
  use Scrybot.LogMacros

  # when this is made configurable, it _must_ be available at compile time for it to be used in pattern matching
  @admin_id 96_197_471_641_812_992

  defguard from_admin(message) when message.author.id == @admin_id

  @spec handlers :: [module()]
  def handlers do
    Application.get_env(
      :scrybot,
      :command_handlers,
      [
        Scrybot.Discord.Command.CardInfo,
        Scrybot.Discord.Command.Core,
        Scrybot.Discord.Command.Replacer,
        Scrybot.Discord.Command.Role,
        # Scrybot.Discord.Command.Pinboard,
        # Scrybot.Discord.Command.Testing
      ]
    )
  end

  @spec react_handlers :: [module()]
  def react_handlers do
    Application.get_env(
      :scrybot,
      :react_handlers,
      [
        # Scrybot.Discord.Command.Pinboard,
        Scrybot.Discord.Command.Turtler3000
        # Scrybot.Discord.Command.Scoreboard
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

  @spec do_command(atom(), message :: map()) :: :ok
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
            bomb(e, Exception.format(:error, e, __STACKTRACE__), message)
        catch
          kind, e ->
            bomb(e, Exception.format(kind, e, __STACKTRACE__), message)
        end
      end)

    :ok
  end

  @spec do_reaction_command(
          atom(),
          Scrybot.Discord.Behaviour.ReactionHandler.mode(),
          reaction :: map()
        ) ::
          :ok
  def do_reaction_command(module, mode, reaction) do
    _ =
      Task.start(fn ->
        try do
          module.do_reaction_command(mode, reaction)
        rescue
          e ->
            error("Command execution failed for: #{inspect(mode)} #{inspect(reaction)}")

            error(Exception.format(:error, e, __STACKTRACE__))
        catch
          kind, e ->
            error("Command execution failed for: #{inspect(mode)} #{inspect(reaction)}")

            error(Exception.format(kind, e, __STACKTRACE__))
        end
      end)

    :ok
  end

  @spec init :: :ok
  def init do
    [handlers(), react_handlers()]
    |> Stream.concat()
    |> Stream.uniq()
    |> Enum.each(&init_once(&1))
  end

  defp bomb(err, trace, message) do
    errmsg =
      case message do
        %Nostrum.Struct.Message{} ->
          "Command execution failed for: #{inspect(message.content)}"

        _ ->
          "Command execution failed for: #{inspect(message)}"
      end

    res =
      Nostrum.Api.create_message(message.channel_id, """
      :bomb: Sorry, an internal error occurred.

      `#{inspect(err)}`

      **Details:**
      ```
      #{trace}
      ```
      """)

    debug(inspect(res))

    _ =
      case res do
        {:error, _reason} ->
          Nostrum.Api.create_message(message.channel_id, """
          :bomb: Sorry, an internal error occurred.

          `#{inspect(err)}`

          Details could not be uploaded due to size. Please check the log.

          msgref `#{inspect(message.id)}`
          """)

        _ ->
          :ok
      end

    error("msgref #{inspect(message.id)}")
    error(errmsg)
    error(trace)
  end
end
