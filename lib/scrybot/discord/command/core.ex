defmodule Scrybot.Discord.Command.Core do
  @moduledoc false
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

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
      |> Embed.put_field("Version", Scrybot.version())
      |> Embed.put_field("Elixir Version", System.version(), true)
      |> Embed.put_field("OTP Version", :erlang.system_info(:otp_release), true)
      |> Embed.put_field("ERTS Version", :erlang.system_info(:version), true)
      |> Embed.put_field("Nostrum Version", Scrybot.version(:nostrum), true)
      |> Embed.put_field("ConCache Version", Scrybot.version(:con_cache), true)
      |> Embed.put_field("Jason Version", Scrybot.version(:jason), true)
      |> Embed.put_field("OPQ Version", Scrybot.version(:opq), true)
      |> Embed.put_field("UUID Version", Scrybot.version(:elixir_uuid), true)
      |> Embed.put_field("Tesla Version", Scrybot.version(:tesla), true)
      |> Embed.put_field("FlexLogger Version", Scrybot.version(:flex_logger), true)
      |> Embed.put_field("LoggerFileBackend Version", Scrybot.version(:logger_file_backend), true)
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
