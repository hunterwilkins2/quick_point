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

  @impl true
  def init(room_id) do
    Process.flag(:trap_exit, true)
    Logger.info("Started new GameState GenServer with state: #{room_id}", ansi_color: :yellow)

    room = Rooms.get_room!(room_id)

    {:ok, %Game{room: room}}
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

    state = %Game{
      state
      | users: Map.put(state.users, pid, user),
        total_users: state.total_users + 1
    }

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

    state = %Game{state | users: Map.delete(state.users, pid), total_users: state.total_users - 1}
    broadcast_state!(state)

    if Enum.count(state.users) == 0 do
      Logger.info("No users in #{state.room.id}. Shutting down...", ansi_color: :yellow)
      Process.exit(self(), :normal)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    Logger.info("GameState #{state.room.id} shutdown", ansi_color: :yellow)
    state
  end

  defp broadcast_state!(state) do
    Phoenix.PubSub.broadcast!(QuickPoint.PubSub, "room:#{state.room.id}", {__MODULE__, state})
  end

  defp process_name(room_id), do: {:via, Registry, {GameRegistry, room_id}}
end
