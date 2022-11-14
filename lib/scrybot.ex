defmodule Scrybot do
  @moduledoc """
  Documentation for Scrybot.
  """

  @version Mix.Project.config()[:version]
  @deps Mix.Project.config()[:deps]

  @spec deps() :: [atom()]
  def deps do
    @deps
    |> Enum.map(fn x ->
      case x do
        {app} -> app
        {app, _} -> app
        {_app, _, [{:runtime, false} | _]} -> :reject
        {app, _, _} -> app
      end
    end)
    |> Enum.reject(fn x -> x == :reject end)
    |> Enum.sort()
  end

  @spec version() :: String.t()
  def version do
    @version
  end

  @spec version(atom()) :: String.t()
  def version(app) do
    resp = :application.get_key(app, :vsn)

    case resp do
      {:ok, vsn} -> vsn |> to_string
      _ -> "unused dep, please report"
    end
  end
end
