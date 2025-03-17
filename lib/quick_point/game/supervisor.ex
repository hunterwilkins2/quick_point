defmodule QuickPoint.Game.Supervisor do
  use DynamicSupervisor
  alias QuickPoint.Game.GameState

  @impl true
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def start_child(room_id) do
    DynamicSupervisor.start_child(__MODULE__, {GameState, room_id})
  end

  def stop(room_id) do
    [{pid, _}] = Registry.lookup(GameRegistry, room_id)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
