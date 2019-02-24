defmodule Scrybot.Discord.Command.Core do
  @moduledoc false
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

  @behaviour Scrybot.Discord.Behaviour.Handler
  @behaviour Scrybot.Discord.Behaviour.CommandHandler

  @impl Scrybot.Discord.Behaviour.Handler
  def init do
    Logger.info("Core command set loaded")
  end

  @impl Scrybot.Discord.Behaviour.Handler
  def allow_bots?, do: false

  @impl Scrybot.Discord.Behaviour.CommandHandler
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

  defp dep_vsns do
    deps =
      Scrybot.deps()
      |> Enum.map(fn x -> ":#{x}$=> #{Scrybot.version(x)}" end)

    dep_vsns({"```\n", deps})
  end

  defp dep_vsns({str, []}), do: (str <> "```") |> align()
  defp dep_vsns({str, [dep | deps]}), do: dep_vsns({"#{str}#{dep}\n", deps})

  # This code is kinda gross; i def want to rewrite it up at some point
  defp align(text) do
    fieldsbyrow =
      text
      |> String.split("\n", trim: true)
      |> Enum.map(fn row -> String.split(row, "$", trim: true) end)

    maxfields =
      fieldsbyrow
      |> Enum.map(fn field -> length(field) end)
      |> Enum.max()

    colwidths =
      fieldsbyrow
      |> Enum.map(fn x -> x ++ List.duplicate("", maxfields - length(x)) end)
      |> List.zip()
      |> Enum.map(fn field ->
        field
        |> Tuple.to_list()
        |> Enum.map(fn x -> String.length(x) end)
        |> Enum.max()
      end)

    fieldsbyrow
    |> Enum.map(fn row ->
      row
      |> Enum.zip(colwidths)
      |> Enum.map(fn {field, width} -> String.pad_trailing(field, width) end)
      |> Enum.join(" ")
      |> String.trim()
    end)
    |> Enum.join("\n")
    # if we dont replace doubled newlines, we wind up with a leading blank line
    |> String.replace("\n\n", "\n")
  end

  defp version(ctx) do
    embed =
      %Embed{}
      |> Embed.put_title("Scrybot")
      |> Embed.put_field("Version", Scrybot.version(), false)
      |> Embed.put_field("Elixir", System.version(), true)
      |> Embed.put_field("OTP", :erlang.system_info(:otp_release) |> to_string, true)
      |> Embed.put_field("ERTS", :erlang.system_info(:version) |> to_string, true)
      |> Embed.put_field("Dependencies", dep_vsns(), false)
      |> Embed.put_color(Colors.success())

    Api.create_message(ctx.channel_id, embed: embed)
  end

  defp quit(ctx) do
    if ctx.author.id == 96_197_471_641_812_992 do
      {_, _} = Api.create_message(ctx.channel_id, content: "Exiting...")
      System.stop()
    end
  end
end
