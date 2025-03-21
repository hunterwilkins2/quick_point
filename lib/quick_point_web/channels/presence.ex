defmodule QuickPointWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :quick_point,
    pubsub_server: QuickPoint.PubSub

  require Logger

  def init(_opts) do
    {:ok, %{}}
  end

  def fetch(_topic, presences) do
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      {key,
       %{
         metas: [meta | metas],
         id: meta.id,
         user: %{id: meta.id, name: meta.name, roles: meta.roles}
       }}
    end
  end

  def handle_metas(
        "online_users:" <> room_id = topic,
        %{joins: joins, leaves: leaves},
        presences,
        state
      ) do
    Logger.info("Users in room #{room_id}: #{Enum.count(presences)}",
      ansi_color: :yellow
    )

    if Enum.count(presences) == 0 do
      QuickPoint.Game.Supervisor.stop(room_id)
    end

    for {user_id, presence} <- joins do
      user_data = %{id: user_id, user: presence.user, metas: Map.fetch!(presences, user_id)}
      msg = {__MODULE__, {:join, user_data}}
      Phoenix.PubSub.broadcast(QuickPoint.PubSub, "proxy:#{topic}", msg)
      # QuickPoint.Game.GameState.add_user(room_id, presence)
    end

    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{id: user_id, user: presence.user, metas: metas}
      msg = {__MODULE__, {:leave, user_data}}
      Phoenix.PubSub.broadcast(QuickPoint.PubSub, "proxy:#{topic}", msg)
      # QuickPoint.Game.GameState.remove_user(room_id, presence)
    end

    {:ok, state}
  end

  def list_online_users(room_id),
    do: list("online_users:#{room_id}") |> Enum.map(fn {_id, presence} -> presence end)

  def track_user(room_id, user_id, params),
    do: track(self(), "online_users:#{room_id}", user_id, params)

  def subscribe(room_id),
    do: Phoenix.PubSub.subscribe(QuickPoint.PubSub, "proxy:online_users:#{room_id}")
end
