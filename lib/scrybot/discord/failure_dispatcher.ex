defmodule Scrybot.Discord.FailureDispatcher do
  @moduledoc false
  use GenServer
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

  @spec init(term()) :: {:ok, :state}
  def init(_) do
    {:ok, :state}
  end

  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def handle_info({_level, _message, :NONE}) do
    # this is called during tests
    :ok
  end

  def handle_info({:warning, message, ctx}, :state) do
    embed =
      %Embed{}
      |> Embed.put_color(Colors.warning())
      |> Embed.put_description(message)

    Api.create_message(ctx.channel_id, embed: embed)

    {:noreply, :state}
  end

  def handle_info({:error, message, ctx}, :state) do
    embed =
      %Embed{}
      |> Embed.put_color(Colors.error())
      |> Embed.put_description(message)

    Api.create_message(ctx.channel_id, embed: embed)

    {:noreply, :state}
  end
end
