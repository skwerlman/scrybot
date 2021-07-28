defmodule Scrybot.Discord.FailureDispatcher do
  @moduledoc false
  use GenServer
  alias Nostrum.Api
  alias Nostrum.Struct.Embed
  alias Scrybot.Discord.Colors

  @typep level :: :success | :info | :warning | :error

  @spec init(term()) :: {:ok, :state}
  def init(_) do
    {:ok, :state}
  end

  @spec start_link([]) :: :ignore | {:error, any} | {:ok, pid}
  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec handle_info({any, any, :NONE}) :: :ok
  def handle_info({_level, _message, :NONE}) do
    # this is called during tests
    :ok
  end

  @spec handle_info({level, any, atom | Nostrum.Struct.Channel.t()}, :state) :: {:noreply, :state}
  def handle_info({_level, embed = %Embed{}, ctx}, :state) do
    _ = Api.create_message(ctx.channel_id, embed: embed)

    {:noreply, :state}
  end

  def handle_info({level, message, ctx}, :state) when is_binary(message) do
    embed =
      %Embed{}
      |> Embed.put_color(Colors.from_atom(level))
      |> Embed.put_description(message)

    case ctx do
      :NONE ->
        :ok

      _ ->
        _ = Api.create_message(ctx.channel_id, embed: embed)
    end

    {:noreply, :state}
  end

  def handle_info({level, message, ctx}, :state) do
    embed =
      %Embed{}
      |> Embed.put_color(Colors.from_atom(level))
      |> Embed.put_description(inspect(message))

    case ctx do
      :NONE ->
        :ok

      _ ->
        _ = Api.create_message(ctx.channel_id, embed: embed)
    end

    {:noreply, :state}
  end
end
