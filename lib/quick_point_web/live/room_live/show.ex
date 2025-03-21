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

    state = GameState.current_state(id)

    {:ok, update_state(socket, state)}
  end

  @impl true
  def handle_event("voted", %{"vote" => vote}, socket) do
    {:noreply, assign(socket, :vote, vote)}
  end

  @impl true
  def handle_info({GameState, new_state}, socket) do
    {:noreply, update_state(socket, new_state)}
  end

  defp update_state(socket, %Game{} = state) do
    users =
      state.users
      |> Enum.map(fn {id, user} -> %{id: id, user: user, vote: Map.get(state.votes, id)} end)

    socket
    |> assign(:room, state.room)
    |> assign(:vote, Map.get(state.votes, socket.assigns.current_user.id))
    |> assign(:game_state, state.state)
    |> stream(:users, users)
  end
end
