defmodule Scrybot.Discord.Command.Role do
  @moduledoc """
  Adds and removes roles to users on command.
  """
  use Scrybot.LogMacros
  alias Scrybot.Discord.Config
  alias Scrybot.Discord.FailureDispatcher
  alias Nostrum.Api
  alias Nostrum.Struct.{Channel, Message, Embed, User}
  require Logger

  @behaviour Scrybot.Discord.Behaviour.Handler
  @behaviour Scrybot.Discord.Behaviour.CommandHandler

  @help """
  Valid role commands:
  `!role add <role>` adds you to that role
  `!role remove <role>` removes you from that role
  `!role list` lists the available roles
  """

  @impl Scrybot.Discord.Behaviour.Handler
  def init do
    info("Role command set loaded")
    :ok
  end

  @impl Scrybot.Discord.Behaviour.Handler
  def allow_bots?, do: false

  @impl Scrybot.Discord.Behaviour.CommandHandler
  def do_command(message = %Message{content: <<"!role add ", role_name::binary>>}) do
    guild = message.guild_id
    config = Config.read_config(guild)
    allowed_role_ids = config["role"]["allowed"]
    info inspect allowed_role_ids

    roles = Api.get_guild_roles!(guild)
    info inspect roles

    allowed_roles =
      allowed_role_ids
      |> Enum.map(fn rid -> Enum.find(roles, fn r -> r.id == rid end) end)
    info inspect allowed_roles

    role = Enum.find(allowed_roles, fn r -> r.name == role_name end)
    info inspect(role)

    if role do
      {:ok, user} = Api.get_guild_member(guild, message.author.id)
      if role.id not in user.roles do
        _ = Api.add_guild_member_role(guild, message.author.id, role.id, "Role Command")
        name = if user.nick, do: user.nick, else: user.user.username
        send(FailureDispatcher, {:success, "Added #{name} to role #{role.name}", message})
      else
        send(FailureDispatcher, {:warning, "You already have that role!", message})
      end
    else
      send(FailureDispatcher, {:error, "No such role: #{role_name}", message})
    end
  end

  @impl Scrybot.Discord.Behaviour.CommandHandler
  def do_command(message = %Message{content: <<"!role remove ", role_name::binary>>}) do
    guild = message.guild_id
    config = Config.read_config(guild)
    allowed_role_ids = config["role"]["allowed"]
    info inspect allowed_role_ids

    roles = Api.get_guild_roles!(guild)
    info inspect roles

    allowed_roles =
      allowed_role_ids
      |> Enum.map(fn rid -> Enum.find(roles, fn r -> r.id == rid end) end)
    info inspect allowed_roles

    role = Enum.find(allowed_roles, fn r -> r.name == role_name end)
    info inspect(role)

    if role do
      {:ok, user} = Api.get_guild_member(guild, message.author.id)
      if role.id in user.roles do
        _ = Api.remove_guild_member_role(guild, message.author.id, role.id, "Role Command")
        name = if user.nick, do: user.nick, else: user.user.username
        send(FailureDispatcher, {:success, "Removed #{name} from role #{role.name}", message})
      else
        send(FailureDispatcher, {:warning, "You don't have that role!", message})
      end
    else
      send(FailureDispatcher, {:error, "No such role: #{role_name}", message})
    end
  end

  @impl Scrybot.Discord.Behaviour.CommandHandler
  def do_command(message = %Message{content: <<"!role list">>}) do
    guild = message.guild_id
    config = Config.read_config(guild)
    allowed_role_ids = config["role"]["allowed"]
    roles = Api.get_guild_roles!(guild)
    allowed_roles =
      allowed_role_ids
      |> Enum.map(fn rid -> Enum.find(roles, fn r -> r.id == rid end) end)

    role_txt =
      allowed_roles
      |> Enum.map(fn r -> " - #{r.name}" end)
      |> Enum.join("\n")

    msg =
      """
      The roles available for adding are:
      #{role_txt}
      """

    send(FailureDispatcher, {:info, msg, message})
  end

  @impl Scrybot.Discord.Behaviour.CommandHandler
  def do_command(message = %Message{content: <<"!role ", _::binary>>}) do
    msg = @help
    send(FailureDispatcher, {:info, msg, message})
  end

  @impl Scrybot.Discord.Behaviour.CommandHandler
  def do_command(message = %Message{content: <<"!role">>}) do
    msg = @help
    send(FailureDispatcher, {:info, msg, message})
  end

  @impl Scrybot.Discord.Behaviour.CommandHandler
  def do_command(_) do
    :ok
  end
end
