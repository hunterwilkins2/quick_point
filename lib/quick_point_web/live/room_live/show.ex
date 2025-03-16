defmodule QuickPointWeb.RoomLive.Show do
  use QuickPointWeb, :live_view

  alias QuickPoint.Rooms
  alias QuickPoint.Tickets
  alias QuickPoint.Tickets.Ticket

  on_mount {QuickPointWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    %{
      room: room,
      total_tickets: total_tickets,
      active_tickets: active_tickets,
      completed_tickets: completed_tickets
    } = Rooms.get_room_and_tickets!(id)

    tickets = Tickets.filter(room, "not_started")

    current_user = socket.assigns.current_user
    roles = Rooms.list_or_create_roles(current_user, room)

    socket = stream(socket, :presences, [])

    socket =
      if connected?(socket) do
        QuickPointWeb.Presence.track_user(room.id, current_user.id, %{
          id: current_user.id,
          name: current_user.name,
          roles: roles |> Enum.map(& &1.role)
        })

        QuickPointWeb.Presence.subscribe(room.id)
        stream(socket, :presences, QuickPointWeb.Presence.list_online_users(room.id))
      else
        socket
      end

    socket =
      socket
      |> assign(:page_title, "Show Room")
      |> assign(:form, to_form(%{"ticket_filter" => "not_started"}))
      |> assign(:room, room)
      |> assign(:total_tickets, total_tickets)
      |> assign(:active_tickets, active_tickets)
      |> assign(:completed_tickets, completed_tickets)
      |> stream(:tickets, tickets)
      |> assign(:is_moderator, Enum.any?(roles, &(&1.role == :moderator)))
      |> assign(:is_player, Enum.any?(roles, &(&1.role == :player)))
      |> assign(:is_observer, Enum.any?(roles, &(&1.role == :observer)))
      |> assign(:vote, "")

    {:ok, socket, temporary_assigns: [ticket: nil]}
  end

  @impl true
  def handle_params(%{"ticket_id" => id}, _, %{assigns: %{live_action: :edit_ticket}} = socket) do
    {:noreply, assign(socket, :ticket, Tickets.get_ticket!(id))}
  end

  @impl true
  def handle_params(_params, _session, %{assigns: %{live_action: :new_ticket}} = socket) do
    {:noreply, assign(socket, :ticket, %Ticket{})}
  end

  @impl true
  def handle_params(_, _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filter", %{"ticket_filter" => filter} = params, socket) do
    {:noreply,
     socket
     |> stream(:tickets, Tickets.filter(socket.assigns.room, filter), reset: true)
     |> assign(:form, to_form(params))}
  end

  @impl true
  def handle_event("voted", %{"vote" => value}, socket) do
    {:noreply, assign(socket, :vote, value)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)

    case Tickets.delete_ticket(socket.assigns.current_user, socket.assigns.room, ticket) do
      {:ok, _} ->
        {:noreply,
         socket
         |> stream_delete(:tickets, ticket)
         |> update_counts(ticket.status, -1)}

      {:error, :unauthorized_action} ->
        {:noreply,
         socket
         |> put_flash(:error, "Only moderators may preform that action")
         |> push_event("restore", %{id: "tickets-#{ticket.id}"})}
    end
  end

  @impl true
  def handle_event("delete-all", _params, socket) do
    filter = socket.assigns.form[:ticket_filter].value

    case Tickets.delete_where(socket.assigns.current_user, socket.assigns.room, filter) do
      {:error, :unauthorized_action} ->
        {:noreply, put_flash(socket, :error, "Only moderators may preform that action")}

      {count, _} ->
        {:noreply,
         socket
         |> stream(:tickets, [], reset: true)
         |> update_counts(filter, -count)}
    end
  end

  @impl true
  def handle_info({QuickPointWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  @impl true
  def handle_info({QuickPointWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  @impl true
  def handle_info({QuickPointWeb.TicketLive.FormComponent, {:saved, ticket}}, socket) do
    filter = socket.assigns.form[:ticket_filter].value

    socket =
      if filter != "completed" do
        stream_insert(socket, :tickets, ticket)
      else
        socket
      end

    {:noreply, update_counts(socket, :not_started, 1)}
  end

  @impl true
  def handle_info({QuickPointWeb.TicketLive.FormComponent, {:edited, ticket}}, socket) do
    {:noreply, stream_insert(socket, :tickets, ticket)}
  end

  defp update_counts(socket, :not_started, count) do
    socket
    |> assign(:active_tickets, socket.assigns.active_tickets + count)
    |> assign(:total_tickets, socket.assigns.total_tickets + count)
  end

  defp update_counts(socket, :completed, count) do
    socket
    |> assign(:completed_tickets, socket.assigns.completed_tickets + count)
    |> assign(:total_tickets, socket.assigns.total_tickets + count)
  end

  defp update_counts(socket, filter, count) when is_bitstring(filter) do
    case filter do
      "not_started" ->
        update_counts(socket, :not_started, count)

      "completed" ->
        update_counts(socket, :completed, count)

      "total" ->
        socket
        |> assign(:active_tickets, 0)
        |> assign(:completed_tickets, 0)
        |> assign(:total_tickets, 0)
    end
  end
end
