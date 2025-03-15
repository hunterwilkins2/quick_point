defmodule QuickPointWeb.RoomLive.Index do
  use QuickPointWeb, :live_view

  alias QuickPoint.Rooms
  alias QuickPoint.Rooms.Room

  on_mount {QuickPointWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    %{moderator: rooms_owned, visited: rooms_visited} = Rooms.list_rooms(user)

    {:ok,
     socket
     |> stream(:rooms_owned, rooms_owned)
     |> stream(:rooms_visited, rooms_visited)
     |> assign(:has_visited_room, Enum.count(rooms_visited) > 0)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Room")
    |> assign(:room, Rooms.get_room!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Room")
    |> assign(:room, %Room{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Rooms")
    |> assign(:room, nil)
  end

  @impl true
  def handle_info({QuickPointWeb.RoomLive.FormComponent, {:saved, room}}, socket) do
    {:noreply, stream_insert(socket, :rooms, room)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    room = Rooms.get_room!(id)

    case Rooms.delete_room(socket.assigns.current_user, room) do
      {:ok, _} ->
        {:noreply, stream_delete(socket, :rooms, room)}

      {:error, :unauthorized_action} ->
        {:noreply,
         socket
         |> put_flash(:error, "Only moderators may preform that action")
         |> push_event("restore", %{id: "rooms_owned-#{room.id}"})}
    end
  end
end
