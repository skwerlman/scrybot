defmodule Scrybot.Discord.Config do
  @moduledoc """
  Allows specifying a TOML config in a discord message (fuck a database).
  """
  use Scrybot.LogMacros
  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Struct.{Channel, Guild}
  require Logger

  @spec read_config(non_neg_integer | Nostrum.Struct.Guild.t()) :: map
  def read_config(guild_id) when is_integer(guild_id) do
    guild = GuildCache.get!(guild_id)
    read_config(guild)
  end

  def read_config(guild = %Guild{}) do
    {conf_channel, _} = guild.channels
    |> Enum.find(fn {_, %Channel{name: name}} -> name == "scry-config" end)

    [msg] = Api.get_channel_messages!(conf_channel, 1)

    {:ok, cfg} = Toml.decode(msg.content)
    cfg
  end
end
