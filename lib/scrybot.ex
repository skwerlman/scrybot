defmodule Scrybot do
  @moduledoc """
  Documentation for Scrybot.
  """

  @version Mix.Project.config()[:version]
  @deps Mix.Project.config()[:deps]

  def deps do
    @deps
    |> Enum.map(fn x ->
      case x do
        {app} -> app
        {app, _} -> app
        {app, _, _} -> app
      end
    end)
  end

  def version do
    @version
  end

  def version(app) do
    resp = :application.get_key(app, :vsn)

    case resp do
      {:ok, vsn} -> vsn
      _ -> "unknown"
    end
  end
end
