defmodule QuickPoint.Game.GameState do
  use GenServer, restart: :transient
  require Logger

  alias QuickPoint.Tickets

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: process_name(room_id))
  end

  def get_game_state(room_id) do
    GenServer.call(process_name(room_id), {:current_state})
  end

  def add_user(room_id, user_presence) do
    GenServer.cast(process_name(room_id), {:add_user, user_presence})
  end

  def remove_user(room_id, user_presence) do
    GenServer.cast(process_name(room_id), {:remove_user, user_presence})
  end

  def vote(room_id, user_id, value) do
    GenServer.cast(process_name(room_id), {:vote, user_id, value})
  end

  def update_active_ticket(room_id) do
    GenServer.cast(process_name(room_id), {:update_active_ticket})
  end

  def next_ticket(room_id) do
    GenServer.cast(process_name(room_id), {:next_ticket})
  end

  @impl true
  def init(room_id) do
    Process.flag(:trap_exit, true)
    Logger.info("Started new GameState GenServer with state: #{room_id}", ansi_color: :yellow)
    active_ticket = Tickets.get_active(room_id)

    {:ok,
     %{
       room_id: room_id,
       game_status: get_status(active_ticket),
       active_ticket: active_ticket,
       users: %{},
       votes: %{},
       total_players: 0,
       total_votes: 0
     }}
  end

  @impl true
  def handle_cast({:vote, user_id, value}, state) do
    votes = Map.put(state.votes, user_id, value)
    total_votes = count_votes(state.users, votes)
    state = %{state | votes: votes, total_votes: total_votes}

    if Map.has_key?(state.users, user_id) do
      state =
        if is_finished_voting(state) do
          %{state | game_status: :show_results}
        else
          state
        end

      broadcast!(
        state.room_id,
        {:vote, Map.get(state.users, user_id), value, total_votes, state.game_status}
      )

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:add_user, presence}, state) do
    users = Map.put(state.users, presence.id, presence.user)
    total_players = count_players(users)
    total_votes = count_votes(users, state.votes)

    broadcast!(
      state.room_id,
      {:join, presence.user, Map.get(state.votes, presence.user.id), total_players, total_votes}
    )

    {:noreply, %{state | users: users, total_players: total_players, total_votes: total_votes}}
  end

  @impl true
  def handle_cast({:remove_user, presence}, state) do
    users = Map.delete(state.users, presence.id)
    total_players = count_players(users)
    total_votes = count_votes(users, state.votes)

    broadcast!(state.room_id, {:leave, presence.user, total_players, total_votes})

    {:noreply, %{state | users: users, total_players: total_players, total_votes: total_votes}}
  end

  @impl true
  def handle_cast({:update_active_ticket}, state) do
    active_ticket = Tickets.get_active(state.room_id)

    state = %{
      state
      | game_status: get_status(active_ticket, state.game_status),
        active_ticket: active_ticket
    }

    broadcast_game_state!(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:next_ticket}, %{game_status: :waiting_to_start} = state) do
    state = %{state | game_status: :voting}
    broadcast_game_state!(state)
    {:noreply, state}
  end

  def handle_cast({:next_ticket}, %{game_status: :show_results} = state) do
    Tickets.update_ticket(state.active_ticket, %{
      effort: get_ticket_effort(state),
      status: :completed
    })

    active_ticket = Tickets.get_active(state.room_id)

    state = %{
      state
      | active_ticket: active_ticket,
        game_status: get_status(active_ticket, :voting),
        votes: %{}
    }

    broadcast_game_state!(state)

    {:noreply, state}
  end

  def handle_cast({:next_ticket}, state), do: {:noreply, state}

  @impl true
  def handle_call({:current_state}, _from, state) do
    users =
      state.users
      |> Enum.map(fn {key, user} -> %{id: key, user: user, vote: Map.get(state.votes, key)} end)

    reply = %{
      game_status: state.game_status,
      active_ticket: state.active_ticket,
      users: users,
      total_players: state.total_players,
      total_votes: state.total_votes
    }

    {:reply, reply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("GameState #{state.room_id} shutdown with reason: #{reason}", ansi_color: :yellow)
    state
  end

  defp broadcast!(room_id, msg),
    do: Phoenix.PubSub.broadcast!(QuickPoint.PubSub, "room:#{room_id}", {__MODULE__, msg})

  defp broadcast_game_state!(state) do
    current_state = %{
      game_status: state.game_status,
      active_ticket: state.active_ticket,
      users: state.users,
      total_players: state.total_players,
      total_votes: state.total_votes
    }

    broadcast!(state.room_id, {:update_state, current_state})
  end

  defp get_ticket_effort(state) do
    Map.values(state.users)
    |> IO.inspect()
    |> Enum.frequencies_by(fn user -> Map.get(state.votes, user.id) end)
    |> Map.values()
    |> Enum.max()
  end

  defp is_finished_voting(state) do
    Map.values(state.users)
    |> Enum.all?(fn user -> Map.get(state.votes, user.id) != nil end)
  end

  defp count_players(users), do: Enum.count(users)

  defp count_votes(users, votes),
    do: Enum.count(votes, fn {user_id, _} -> Map.has_key?(users, user_id) end)

  defp get_status(nil), do: :game_over

  defp get_status(_ticket), do: :waiting_to_start

  defp get_status(nil, _status), do: :game_over

  defp get_status(_ticket, :game_over), do: :waiting_to_start

  defp get_status(_ticket, status), do: status

  defp process_name(room_id), do: {:via, Registry, {GameRegistry, room_id}}
end
