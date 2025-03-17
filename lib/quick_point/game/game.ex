defmodule QuickPoint.Game.GameState do
  use GenServer, restart: :transient
  require Logger

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
    {:ok, %{room_id: room_id, users: %{}, votes: %{}, total_users: 0, total_votes: 0}}
  end

  @impl true
  def handle_cast({:vote, user_id, value}, state) do
    if Map.has_key?(state.users, user_id) do
      broadcast!(state.room_id, {:vote, Map.get(state.users, user_id), value})
    end

    {:noreply, %{state | votes: Map.put(state.votes, user_id, value)}}
  end

  @impl true
  def handle_cast({:add_user, presence}, state) do
    users = Map.put(state.users, presence.id, presence.user)
    broadcast!(state.room_id, {:join, presence.user, Map.get(state.votes, presence.user.id)})
    {:noreply, %{state | users: users, total_users: Map.keys(users) |> Enum.count()}}
  end

  @impl true
  def handle_cast({:remove_user, presence}, state) do
    users = Map.delete(state.users, presence.id)
    broadcast!(state.room_id, {:leave, presence.user})
    {:noreply, %{state | users: users, total_users: Map.keys(users) |> Enum.count()}}
  end

  @impl true
  def handle_call({:current_state}, _from, state) do
    users =
      state.users
      |> Enum.map(fn {key, user} -> %{id: key, user: user, vote: Map.get(state.votes, key)} end)

    {:reply, %{users: users}, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("GameState #{state.room_id} shutdown with reason: #{reason}", ansi_color: :yellow)
    state
  end

  defp broadcast!(room_id, msg) do
    Phoenix.PubSub.broadcast!(QuickPoint.PubSub, "room:#{room_id}", {__MODULE__, msg})
  end

  defp process_name(room_id) do
    {:via, Registry, {GameRegistry, room_id}}
  end
end
