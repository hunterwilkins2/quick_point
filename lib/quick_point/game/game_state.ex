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

  def update_room(%Room{} = room), do: GenServer.cast(process_name(room.id), {:update_room, room})

  @impl true
  def init(room_id) do
    Process.flag(:trap_exit, true)
    Logger.info("Started new GameState GenServer with state: #{room_id}", ansi_color: :yellow)

    room = Rooms.get_room!(room_id)

    {:ok, %Game{room: room}}
  end

  @impl true
  def handle_cast({:update_room, %Room{} = room}, state) do
    Logger.debug("Updating room name to #{room.name}", anasi_color: :blue)

    state = %Game{state | room: room}
    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def terminate(reason, state) do
    Logger.info("GameState #{state.room_id} shutdown with reason: #{reason}", ansi_color: :yellow)
    state
  end

  defp broadcast_state!(state) do
    Phoenix.PubSub.broadcast!(QuickPoint.PubSub, "room:#{state.room.id}", {__MODULE__, state})
  end

  defp process_name(room_id), do: {:via, Registry, {GameRegistry, room_id}}
end
