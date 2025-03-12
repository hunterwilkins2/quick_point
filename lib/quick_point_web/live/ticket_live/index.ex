defmodule QuickPointWeb.TicketLive.Index do
  use QuickPointWeb, :live_view

  alias QuickPoint.Tickets
  alias QuickPoint.Tickets.Ticket
  alias QuickPoint.Rooms

  on_mount {QuickPointWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    room = Rooms.get_room!(room_id)

    {:ok,
     socket
     |> assign(:room, room)
     |> stream(:tickets, Tickets.list_tickets(room))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Ticket")
    |> assign(:ticket, Tickets.get_ticket!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Ticket")
    |> assign(:ticket, %Ticket{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Tickets")
    |> assign(:ticket, nil)
  end

  @impl true
  def handle_info({QuickPointWeb.TicketLive.FormComponent, {:saved, ticket}}, socket) do
    {:noreply, stream_insert(socket, :tickets, ticket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)
    {:ok, _} = Tickets.delete_ticket(ticket)

    {:noreply, stream_delete(socket, :tickets, ticket)}
  end
end
