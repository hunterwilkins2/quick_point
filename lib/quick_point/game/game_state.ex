defmodule QuickPoint.Game.GameState do
  use GenServer, restart: :transient
  require Logger

  alias QuickPoint.Game.Game
  alias QuickPoint.Rooms
  alias QuickPoint.Rooms.Room

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: process_name(room_id))
  end

  def current_state(room_id), do: GenServer.call(process_name(room_id), :get_state)

  def add_player(pid, room_id, user),
    do: GenServer.cast(process_name(room_id), {:add_player, pid, user})

  def update_room(%Room{} = room), do: GenServer.cast(process_name(room.id), {:update_room, room})

  def vote(room_id, user, vote),
    do: GenServer.cast(process_name(room_id), {:vote, user, vote})

  def clear_votes(room_id), do: GenServer.cast(process_name(room_id), :clear_votes)

  def end_voting(room_id), do: GenServer.cast(process_name(room_id), :end_voting)

  def skip_ticket(room_id), do: GenServer.cast(process_name(room_id), :skip_ticket)

  def next_ticket(room_id), do: GenServer.cast(process_name(room_id), :next_ticket)

  @impl true
  def init(room_id) do
    Process.flag(:trap_exit, true)
    Logger.info("Started new GameState GenServer with state: #{room_id}", ansi_color: :yellow)

    room = Rooms.get_room!(room_id)

    {:ok, %Game{room: room, state: :voting}}
  end

  @impl true
  def handle_cast({:update_room, %Room{} = room}, %Game{} = state) do
    Logger.debug("Updating room name to #{room.name}", ansi_color: :blue)

    state = %Game{state | room: room}
    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_player, pid, user}, %Game{} = state) do
    Logger.debug("Added #{user.name} to #{state.room.id} from #{inspect(pid)}", ansi_color: :blue)
    Process.monitor(pid)

    state =
      state
      |> Map.replace!(:users, Map.put(state.users, pid, user))
      |> Map.replace!(:total_users, state.total_users + 1)
      |> count_votes()

    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:vote, user, vote}, %Game{} = state) do
    Logger.debug("#{user.name} in #{state.room.id} voted #{vote}", ansi_color: :blue)

    votes = Map.put(state.votes, user.id, vote)

    state =
      state
      |> Map.replace!(:votes, votes)
      |> Map.replace!(:total_votes, count_votes(state.users, votes))
      |> get_state()

    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:clear_votes, %Game{} = state) do
    Logger.debug("Clearing votes in #{state.room.id}", ansi_color: :blue)

    state = %Game{state | state: :voting, votes: %{}, total_votes: 0}
    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:end_voting, %Game{} = state) do
    Logger.debug("Voting manually ended in #{state.room.id}", ansi_color: :blue)

    state = %Game{state | state: :show_results}
    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:skip_ticket, %Game{} = state) do
    Logger.debug("Skipping ticket in #{state.room.id}", ansi_color: :blue)

    state = %Game{state | state: :voting, votes: %{}, total_votes: 0}
    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:next_ticket, %Game{} = state) do
    Logger.debug("Moving to next ticket in #{state.room.id}", ansi_color: :blue)

    state = %Game{state | state: :voting, votes: %{}, total_votes: 0}
    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, %Game{} = state), do: {:reply, state, state}

  @impl true
  def handle_info({:DOWN, _, :process, pid, reason}, %Game{} = state) do
    Logger.debug("#{inspect(pid)} exited with #{inspect(reason)}", ansi_color: :blue)

    Logger.debug("Removed #{Map.get(state.users, pid).name} from #{state.room.id}",
      ansi_color: :blue
    )

    state =
      state
      |> Map.replace!(:users, Map.delete(state.users, pid))
      |> Map.replace!(:total_users, state.total_users - 1)
      |> count_votes()
      |> get_state()

    broadcast_state!(state)

    if Enum.count(state.users) == 0 do
      Logger.info("No users in #{state.room.id}. Shutting down...", ansi_color: :yellow)
      Process.exit(self(), :normal)
    end

    {:noreply, state}
  end

  def handle_info({:EXIT, _from, reason}, state), do: {:stop, reason, state}

  @impl true
  def terminate(_reason, state) do
    Logger.info("GameState #{state.room.id} shutdown", ansi_color: :yellow)
    state
  end

  defp broadcast_state!(state) do
    Phoenix.PubSub.broadcast!(QuickPoint.PubSub, "room:#{state.room.id}", {__MODULE__, state})
  end

  defp count_votes(state) do
    %Game{state | total_votes: count_votes(state.users, state.votes)}
  end

  defp count_votes(users, votes) do
    users
    |> Enum.count(fn {_, user} -> Map.has_key?(votes, user.id) end)
  end

  defp get_state(%Game{state: :voting, total_users: users, total_votes: votes} = state)
       when users == votes do
    %Game{state | state: :show_results}
  end

  defp get_state(%Game{state: :voting} = state), do: state

  defp get_state(%Game{state: :show_results} = state), do: state

  defp process_name(room_id), do: {:via, Registry, {GameRegistry, room_id}}
end
