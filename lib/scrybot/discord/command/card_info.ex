defmodule Scrybot.Discord.Command.CardInfo do
  @moduledoc false
  require Logger
  alias Nostrum.Struct.Embed
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User
  alias Scrybot.Discord.Emoji

  def init do
    Logger.info("CardInfo command set loaded")
  end

  def do_command(%Message{author: %User{bot: bot}} = message) when bot in [false, nil] do
    cap =
      Regex.named_captures(
        ~r/.*\[\[(?<card_name>.*)\]\].*/,
        message.content
      )

    {embed, info} =
      case cap do
        nil ->
          nil

        _ ->
          cap["card_name"]
          |> get_card_info()
          |> case do
            {:ok, %{body: info}} ->
              {build_card_embed(info), info}

            {:error, reason} ->
              notify_error(reason, message.channel_id)
              {nil, nil}
          end
      end

    if embed do
      Logger.warn("TRYING TO POST")

      case Nostrum.Api.create_message(message.channel_id, embed: embed) do
        {:ok, _} ->
          :ok

        error ->
          Logger.error(inspect(error))

          notify_error!(
            %Embed{
              description: "```\n#{inspect(error)}\n```",
              title: "Nostrum Error!",
              color: 0xE74C3C
            },
            message.channel_id
          )
      end

      rulings =
        case get_rulings(info["id"]) do
          {:ok, %{body: resp}} -> resp["data"]
          {:error, reason} -> notify_error(reason, message.channel_id)
        end

      ruling_embed =
        %Embed{}
        |> put_rulings(rulings)
        |> Embed.put_footer(
          # case Enum.random(1..10000) do
          #   1..9999 -> "data sourced from Scryfall"
          #   10000 -> "data forcefully ripped from the cold, dead hands of Scryfall"
          # end,
          "data sourced from Scryfall",
          "https://pbs.twimg.com/profile_images/786276514400702464/7k4AEH78_400x400.jpg"
        )

      case Nostrum.Api.create_message(message.channel_id, embed: ruling_embed) do
        {:ok, _} ->
          :ok

        error ->
          Logger.error(inspect(error))

          notify_error!(
            %Embed{
              description: "```\n#{inspect(error)}\n```",
              title: "Nostrum Error!",
              color: 0xE74C3C
            },
            message.channel_id
          )
      end
    end
  end

  defp build_card_embed(card_info) do
    %Embed{}
    |> Embed.put_title(
      md_escape(card_info["name"]) <> " " <> Emoji.emojify(card_info["mana_cost"])
    )
    |> Embed.put_url(card_info["scryfall_uri"])
    |> Embed.put_description(format_description(card_info))
    |> put_legalities(card_info["legalities"])
    |> Embed.put_image(card_info["image_uris"]["art_crop"])
  end

  defp put_rulings(embed, []), do: embed

  defp put_rulings(embed, [ruling | rulings]) do
    embed
    |> Embed.put_field("Ruling #{ruling["published_at"]}", Emoji.emojify(ruling["comment"]))
    |> put_rulings(rulings)
  end

  defp put_legalities(embed, legalities) do
    legal_formats =
      legalities
      |> Map.to_list()
      |> Enum.filter(fn {_, v} -> v == "legal" end)
      |> Enum.map(fn {k, _} -> "- #{k}" end)

    legal_group_1 =
      legal_formats
      |> Enum.take_every(2)
      |> Enum.join("\n")

    legal_group_2 =
      legal_formats
      |> Enum.drop(1)
      |> Enum.take_every(2)
      |> Enum.join("\n")

    case {legal_group_1, legal_group_1} do
      {"", ""} ->
        embed
        |> Embed.put_field("Legal in", "- nothing", true)

      {_, ""} ->
        embed
        |> Embed.put_field("Legal in", legal_group_1, true)

      {_, _} ->
        embed
        |> Embed.put_field("Legal in", legal_group_1, true)
        |> Embed.put_field("\u200D", legal_group_2, true)
    end
  end

  defp md_escape(text) do
    text
    |> String.replace("_", "\\_")
    |> String.replace("~", "\\~")
    |> String.replace("*", "\\*")
    |> String.replace("`", "\\`")
    |> String.replace(">", "\\>")
  end

  defp format_description(card) do
    type = card["type_line"]

    text =
      case card["oracle_text"] do
        nil ->
          ""

        oracle ->
          oracle
          |> String.replace("\n", "\n\n")
          |> Emoji.emojify()
      end

    power = card["power"]
    toughness = card["toughness"]

    pt =
      if power && toughness do
        "**#{power}/#{toughness}**\n"
      else
        ""
      end

    case card["flavor_text"] do
      nil -> "**#{type}**\n#{pt}#{text}"
      flavor -> "**#{type}**\n#{pt}#{text}\n———\n_#{flavor}_"
    end
  end

  defp get_card_info(card_name) do
    Scrybot.Scryfall.Api.cards_named(card_name, false)
  end

  defp get_rulings(cardid) do
    Process.sleep(125)
    Scrybot.Scryfall.Api.rulings(cardid)
  end

  defp notify_error(reason, channel) do
    Logger.error(inspect(reason))
    Nostrum.Api.create_message(channel, embed: reason)
  end

  defp notify_error!(reason, channel) do
    Logger.error(inspect(reason))
    Nostrum.Api.create_message!(channel, embed: reason)
  end
end
