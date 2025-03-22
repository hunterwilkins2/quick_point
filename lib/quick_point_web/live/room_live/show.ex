defmodule QuickPointWeb.RoomLive.Show do
  use QuickPointWeb, :live_view
  require Logger

  alias QuickPoint.Game.GameState
  alias QuickPoint.Game.Game

  on_mount {QuickPointWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    QuickPoint.Game.Supervisor.start_child(id)
    Phoenix.PubSub.subscribe(QuickPoint.PubSub, "room:#{id}")

    if connected?(socket) do
      GameState.add_player(self(), id, socket.assigns.current_user)
    end

    state = GameState.current_state(id)

    {:ok,
     update_state(socket, state)
     |> assign(is_moderator: true)}
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
  end
end
