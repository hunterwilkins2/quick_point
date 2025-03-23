defmodule QuickPointWeb.RoomLive.Show do
  use QuickPointWeb, :live_view
  require Logger

  alias QuickPoint.Game.GameState
  alias QuickPoint.Game.Game
  alias QuickPoint.Tickets
  alias QuickPoint.Tickets.Ticket

  on_mount {QuickPointWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    QuickPoint.Game.Supervisor.start_child(id)
    Phoenix.PubSub.subscribe(QuickPoint.PubSub, "room:#{id}")

    if connected?(socket) do
      GameState.add_player(self(), id, socket.assigns.current_user)
    end

    state = GameState.current_state(id)

    socket =
      socket
      |> assign(is_moderator: true)
      |> assign(ticket_filter: "not_started")
      |> update_state(state)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit_ticket, %{"ticket_id" => id}) do
    socket
    |> assign(:page_title, "Edit Ticket")
    |> assign(:ticket, Tickets.get_ticket!(id))
  end

  defp apply_action(socket, :new_ticket, _params) do
    socket
    |> assign(:page_title, "New Ticket")
    |> assign(:ticket, %Ticket{})
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, socket.assigns.room.name)
    |> assign(:ticket, nil)
  end

  @impl true
  def handle_event("voted", %{"vote" => vote}, socket) do
    GameState.vote(socket.assigns.room.id, socket.assigns.current_user, vote)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear-votes", _params, socket) do
    GameState.clear_votes(socket.assigns.room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("end-voting", _params, socket) do
    GameState.end_voting(socket.assigns.room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("skip-ticket", _params, socket) do
    GameState.skip_ticket(socket.assigns.room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("next-ticket", _params, socket) do
    GameState.next_ticket(socket.assigns.room.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"ticket_filter" => filter}, socket) do
    state = GameState.current_state(socket.assigns.room.id)
    {:noreply, socket |> assign(ticket_filter: filter) |> update_state(state)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ticket = Tickets.get_ticket!(id)

    case Tickets.delete_ticket(socket.assigns.current_user, socket.assigns.room, ticket) do
      {:ok, _} ->
        GameState.delete_ticket(socket.assigns.room.id, ticket)
        {:noreply, socket}

      {:error, :unauthorized_action} ->
        {:noreply, put_flash(socket, :error, "Only moderators may preform that action")}
    end
  end

  @impl true
  def handle_event("delete-all", _params, socket) do
    case Tickets.delete_where(
           socket.assigns.current_user,
           socket.assigns.room,
           socket.assigns.ticket_filter
         ) do
      {:error, :unauthorized_action} ->
        {:noreply, put_flash(socket, :error, "Only moderators may preform that action")}

      {_, _} ->
        GameState.delete_all_tickets(socket.assigns.room.id, socket.assigns.ticket_filter)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({GameState, new_state}, socket), do: {:noreply, update_state(socket, new_state)}

  defp update_state(socket, %Game{} = state) do
    users =
      state.users
      |> Enum.map(fn {_, user} ->
        %{id: user.id, user: user, vote: Map.get(state.votes, user.id)}
      end)

    socket
    |> assign(:room, state.room)
    |> assign(:vote, Map.get(state.votes, socket.assigns.current_user.id))
    |> assign(:game_state, state.state)
    |> stream(:users, users, reset: true)
    |> assign(:total_users, state.total_users)
    |> assign(:total_votes, state.total_votes)
    |> assign(:active_ticket, state.active_ticket)
    |> stream(:tickets, filter_tickets(state.tickets, socket.assigns.ticket_filter), reset: true)
    |> assign(:total_tickets_not_started, state.total_tickets_not_started)
    |> assign(:total_tickets_completed, state.total_tickets_completed)
    |> assign(:total_tickets, state.total_tickets)
    |> assign(:dataset, create_dataset(state.votes))
  end

  defp filter_tickets(tickets, "total"), do: tickets

  defp filter_tickets(tickets, "not_started"),
    do: Enum.filter(tickets, &(&1.status == :not_started))

  defp filter_tickets(tickets, "completed"), do: Enum.filter(tickets, &(&1.status == :completed))

  defp create_dataset(votes) do
    data =
      Map.values(votes)
      |> Enum.map(&String.to_integer/1)
      |> Enum.frequencies()

    %{
      labels: Map.keys(data),
      datasets: [
        %{
          data: Map.values(data)
        }
      ]
    }
  end
end
