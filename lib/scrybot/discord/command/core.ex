defmodule Scrybot.Discord.Command.Core do
  @moduledoc false
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

  @version Mix.Project.config()[:version]

  def init do
    Logger.info("Core command set loaded")
  end

  def allow_bots?, do: false

  def do_command(message) do
    case message.content do
      "!!quit now" ->
        quit(message)

      ".scry version" ->
        version(message)

      _ ->
        :ok
    end
  end

  defp version(ctx) do
    embed =
      %Embed{}
      |> Embed.put_title("Scrybot")
      |> Embed.put_field("Version", @version, true)
      |> Embed.put_color(Colors.success())

    Api.create_message(ctx.channel_id, embed: embed)
  end

  defp quit(ctx) do
    if ctx.author.id == 96_197_471_641_812_992 do
      Api.create_message(ctx.channel_id, content: "Exiting...")
      System.stop()
    end
  end
end
