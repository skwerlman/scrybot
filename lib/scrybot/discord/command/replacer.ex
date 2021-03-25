defmodule Scrybot.Discord.Command.Replacer do
  @moduledoc false
  use Scrybot.LogMacros
  alias Nostrum.Api
  alias Nostrum.Struct.{Embed, User}
  alias Scrybot.Discord.{Colors, Emoji}

  @behaviour Scrybot.Discord.Behaviour.Handler
  @behaviour Scrybot.Discord.Behaviour.CommandHandler

  @impl Scrybot.Discord.Behaviour.Handler
  def allow_bots?, do: false

  @impl Scrybot.Discord.Behaviour.Handler
  def init do
    info("Replacer loaded")
    :ok
  end

  @impl Scrybot.Discord.Behaviour.CommandHandler
  # @spec do_command(Nostrum.Struct.Message.t()) :: :ok
  def do_command(message) when is_struct(message) do
    msg =
      message.content
      |> Emoji.emojify()
      |> clean_links()

    _ =
      if message.content != msg do
        _ = Api.create_message!(message.channel_id, embed: embed(msg, message))
        Api.delete_message!(message)
      end

    :ok
  end

  defp clean_links(msg) do
    # TODO url rules
    msg
  end

  defp embed(processed_message, ctx) do
    user = ctx.author()

    %Embed{}
    |> Embed.put_author(user.username, "", User.avatar_url(user))
    |> Embed.put_color(Colors.info())
    |> Embed.put_description(processed_message)
  end
end
