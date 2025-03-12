defmodule QuickPointWeb.TicketLive.Show do
  use QuickPointWeb, :live_view

  alias QuickPoint.Tickets
  alias QuickPoint.Rooms

  on_mount {QuickPointWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"room_id" => room_id, "id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:ticket, Tickets.get_ticket!(id))
     |> assign(:room, Rooms.get_room!(room_id))}
  end

  defp page_title(:show), do: "Show Ticket"
  defp page_title(:edit), do: "Edit Ticket"
end
