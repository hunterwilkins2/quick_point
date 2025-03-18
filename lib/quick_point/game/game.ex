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

  @impl true
  def init(room_id) do
    Process.flag(:trap_exit, true)
    Logger.info("Started new GameState GenServer with state: #{room_id}", ansi_color: :yellow)
    active_ticket = Tickets.get_active(room_id)

    {:ok,
     %{
       room_id: room_id,
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

    if Map.has_key?(state.users, user_id) do
      broadcast!(
        state.room_id,
        {:vote, Map.get(state.users, user_id), value, total_votes}
      )
    end

    {:noreply, %{state | votes: votes}}
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
  def handle_call({:current_state}, _from, state) do
    users =
      state.users
      |> Enum.map(fn {key, user} -> %{id: key, user: user, vote: Map.get(state.votes, key)} end)

    reply = %{
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

  defp broadcast!(room_id, msg) do
    Phoenix.PubSub.broadcast!(QuickPoint.PubSub, "room:#{room_id}", {__MODULE__, msg})
  end

  defp count_players(users) do
    Enum.count(users)
  end

  defp count_votes(users, votes) do
    Enum.count(votes, fn {user_id, _} -> Map.has_key?(users, user_id) end)
  end

  defp process_name(room_id) do
    {:via, Registry, {GameRegistry, room_id}}
  end
end
