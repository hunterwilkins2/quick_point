defmodule QuickPoint.Game.GameState do
  use GenServer, restart: :transient
  require Logger

  alias QuickPoint.Game.Game

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: process_name(room_id))
  end

  @impl true
  def init(room_id) do
    Process.flag(:trap_exit, true)
    Logger.info("Started new GameState GenServer with state: #{room_id}", ansi_color: :yellow)

    {:ok, %Game{}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("GameState #{state.room_id} shutdown with reason: #{reason}", ansi_color: :yellow)
    state
  end

  defp process_name(room_id), do: {:via, Registry, {GameRegistry, room_id}}
end
