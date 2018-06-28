defmodule Scrybot.Discord.Command.Core do
  @moduledoc false
  require Logger
  alias Nostrum.Api

  def init do
    Logger.info("Core command set loaded")
  end

  def allow_bots?, do: false

  def do_command(message) do
    if message.content == "!!quit now" do
      quit(message)
    end
  end

  defp quit(ctx) do
    if ctx.author.id == 96_197_471_641_812_992 do
      Api.create_message(ctx.channel_id, content: "Exiting...")
      System.stop()
    end
  end
end
