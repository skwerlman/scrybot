defmodule Scrybot.Discord.Command.Core do
  @moduledoc false
  use Scrybot.LogMacros
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

  @admin_id 96_197_471_641_812_992

  @behaviour Scrybot.Discord.Behaviour.Handler
  @behaviour Scrybot.Discord.Behaviour.CommandHandler

  @impl Scrybot.Discord.Behaviour.Handler
  def init do
    info("Core command set loaded")
  end

  @impl Scrybot.Discord.Behaviour.Handler
  def allow_bots?, do: false

  @impl Scrybot.Discord.Behaviour.CommandHandler
  @spec do_command(Nostrum.Struct.Message.t()) :: :ok
  def do_command(message) do
    case message.content do
      "!!quit now" ->
        quit(message)

      ".scry version" ->
        version(message)

      ".scry rule_reload" ->
        rule_reload(message)

      _ ->
        :ok
    end
  end

  defp dep_vsns do
    deps =
      Scrybot.deps()
      |> Enum.map(fn x -> ":#{x}$=> #{Scrybot.version(x)}" end)

    dep_vsns("```\n", deps)
  end

  defp dep_vsns(str, []), do: (str <> "```") |> align()
  defp dep_vsns(str, [dep | deps]), do: dep_vsns("#{str}#{dep}\n", deps)

  # This code is kinda gross; i def want to rewrite it up at some point
  defp align(text) do
    fieldsbyrow =
      text
      |> String.split("\n", trim: true)
      |> Enum.map(fn row -> String.split(row, "$", trim: true) end)

    maxfields =
      fieldsbyrow
      |> Stream.map(fn field -> length(field) end)
      |> Enum.max()

    colwidths =
      fieldsbyrow
      |> Stream.map(fn x -> x ++ List.duplicate("", maxfields - length(x)) end)
      |> Stream.zip()
      |> Enum.map(fn field ->
        field
        |> Tuple.to_list()
        |> Stream.map(fn x -> String.length(x) end)
        |> Enum.max()
      end)

    fieldsbyrow
    |> Stream.map(fn row ->
      row
      |> Stream.zip(colwidths)
      |> Stream.map(fn {field, width} -> String.pad_trailing(field, width) end)
      |> Enum.join(" ")
      |> String.trim()
    end)
    |> Enum.join("\n")
    # if we dont replace doubled newlines, we wind up with a leading blank line
    |> String.replace("\n\n", "\n")
  end

  defp rule_reload(ctx) do
    _ = Api.start_typing(ctx.channel_id)
    start_time = Time.utc_now()

    embed =
      try do
        if ctx.author.id != @admin_id do
          throw(:unauthorized)
        end

        rules =
          :current
          |> LibJudge.get!()
          |> LibJudge.tokenize()

        Application.put_env(:scrybot, :rules, rules, timeout: 15_000)
      rescue
        err ->
          %Embed{}
          |> Embed.put_title("Reload Failed")
          |> Embed.put_description("""
          An error occurred while reloading:
          ```
          #{err}
          ```
          """)
          |> Embed.put_color(Colors.error())
      catch
        :exit, {:timeout, {:gen_server, :call, [_, {:set_env, _, _, _, _}, _]}} ->
          %Embed{}
          |> Embed.put_title("Reload Failed")
          |> Embed.put_description("""
          The call to `put_env` timed out!
          """)
          |> Embed.put_color(Colors.error())

        :unauthorized ->
          %Embed{}
          |> Embed.put_title("Reload Failed")
          |> Embed.put_description("""
          Sorry, only bot admins can reload the rules.
          """)
          |> Embed.put_color(Colors.error())
      else
        _ ->
          # FIXME: Temp filter until this is added to lib_judge
          filter = fn
            {:rule, _} -> true
            _ -> false
          end

          rule_count =
            Application.get_env(:scrybot, :rules, [])
            |> Stream.filter(filter)
            |> Enum.count()

          other_count =
            Application.get_env(:scrybot, :rules, [])
            |> Stream.reject(filter)
            |> Enum.count()

          finish_time = Time.utc_now()

          difference = Time.diff(finish_time, start_time, :millisecond)

          %Embed{}
          |> Embed.put_title("Rules reloaded!")
          |> Embed.put_description("""
          Loaded #{rule_count} rules and #{other_count} non-rule tokens in #{difference} ms.
          """)
          |> Embed.put_color(Colors.success())
      end

    _ = Api.create_message(ctx.channel_id, embed: embed)

    :ok
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

    _ = Api.create_message(ctx.channel_id, embed: embed)

    :ok
  end

  defp quit(ctx) do
    if ctx.author.id == @admin_id do
      {_, _} = Api.create_message(ctx.channel_id, content: "Exiting...")
      System.stop()
      :ok
    end
  end
end
