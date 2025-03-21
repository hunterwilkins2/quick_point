defmodule QuickPointWeb.RoomLive.Show do
  use QuickPointWeb, :live_view
  require Logger

  alias QuickPoint.Rooms

  on_mount {QuickPointWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    room = Rooms.get_room!(id)

    Phoenix.PubSub.subscribe(QuickPoint.PubSub, "room:#{room.id}")

    socket =
      socket
      |> assign(:room, room)

    {:ok, socket}
  end

  @impl true
  def handle_info({QuickPointWeb.RoomLive.FormComponent, {:saved, room}}, socket) do
    {:noreply, assign(socket, :room, room)}
  end
end
