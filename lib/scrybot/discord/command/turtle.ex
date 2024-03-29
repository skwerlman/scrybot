defmodule Scrybot.Discord.Command.Turtler3000 do
  @moduledoc false
  use Scrybot.LogMacros
  alias Nostrum.Api
  alias Nostrum.Cache.Me
  # alias Nostrum.Struct.Channel
  # alias Nostrum.Struct.Message
  alias Nostrum.Struct.User

  @behaviour Scrybot.Discord.Behaviour.Handler
  @behaviour Scrybot.Discord.Behaviour.ReactionHandler

  @turtle "🐢"

  @impl Scrybot.Discord.Behaviour.Handler
  @spec init :: :ok
  def init do
    info("Turtler 3000 reaction module loaded")
    :ok
  end

  @impl Scrybot.Discord.Behaviour.Handler
  def allow_bots?, do: false

  @impl Scrybot.Discord.Behaviour.ReactionHandler
  @spec do_reaction_command(Scrybot.Discord.Behaviour.ReactionHandler.mode(), map()) :: :ok
  def do_reaction_command(:add, %{
        channel_id: channel_id,
        emoji: %{name: @turtle},
        message_id: message_id
      }) do
    # Get our account ID
    %User{id: my_id} = Me.get()

    # Get a list of users who reacted to the message
    {:ok, users} = Api.get_reactions(channel_id, message_id, @turtle)

    # Get a list of user IDs for the people who reacted
    ids = users |> Enum.map(fn x -> x.id end)

    # If we aren't in the list (i.e. we haven't reacted yet)
    _ =
      if my_id not in ids do
        # Add a reaction to the message
        Api.create_reaction(channel_id, message_id, @turtle)

        # # Get the ID of the person who posted the message
        # {:ok, %Message{author: %User{id: user_id}}} =
        #   Api.get_channel_message(channel_id, message_id)
        #
        # # Open a DM with them
        # {:ok, %Channel{id: dm_channel_id}} = Api.create_dm(user_id)
        #
        # # Lol
        # Api.create_message(dm_channel_id, "you got turtled, lmao")
      end

    :ok
  end

  @impl Scrybot.Discord.Behaviour.ReactionHandler
  def do_reaction_command(:remove, %{
        channel_id: channel_id,
        emoji: %{name: @turtle},
        message_id: message_id
      }) do
    me = Me.get()
    {:ok, users} = Api.get_reactions(channel_id, message_id, @turtle)

    count = users |> Enum.count()

    _ =
      if count == 1 and List.first(users).id == me.id do
        Api.delete_own_reaction(channel_id, message_id, @turtle)
      end

    :ok
  end

  @impl Scrybot.Discord.Behaviour.ReactionHandler
  def do_reaction_command(_mode, _reaction), do: :ok
end
