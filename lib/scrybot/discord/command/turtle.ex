defmodule Scrybot.Discord.Command.Turtler3000 do
  @moduledoc false
  alias Nostrum.Api
  alias Nostrum.Cache.Me
  alias Nostrum.Struct.Emoji
  require Logger

  def init do
    Logger.info("Turtler 3000 reaction module loaded")
  end

  def allow_bots?, do: false

  def do_reaction_command(:add, %{
        channel_id: channel_id,
        emoji: %{name: "🐢" = emoji},
        message_id: message_id
      }) do
    Api.create_reaction(channel_id, message_id, emoji)
  end

  def do_reaction_command(:remove, %{
        channel_id: channel_id,
        emoji: %{name: "🐢" = emoji},
        message_id: message_id
      }) do
    me = Me.get()
    {:ok, users} = Api.get_reactions(channel_id, message_id, emoji)

    count =
      users
      |> Enum.count()

    if count == 1 and List.first(users).id == me.id do
      Api.delete_own_reaction(channel_id, message_id, emoji)
    end
  end

  def do_reaction_command(_mode, _reaction), do: :ok
end
