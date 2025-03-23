defmodule QuickPoint.Game.GameState do
  use GenServer, restart: :transient
  require Logger

  alias QuickPoint.Game.Game
  alias QuickPoint.Rooms
  alias QuickPoint.Rooms.Room
  alias QuickPoint.Tickets
  alias QuickPoint.Tickets.Ticket

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

  def add_ticket(room_id, ticket),
    do: GenServer.cast(process_name(room_id), {:add_ticket, ticket})

  def edit_ticket(room_id, ticket),
    do: GenServer.cast(process_name(room_id), {:edit_ticket, ticket})

  def delete_ticket(room_id, ticket),
    do: GenServer.cast(process_name(room_id), {:delete_ticket, ticket})

  def delete_all_tickets(room_id, filter),
    do: GenServer.cast(process_name(room_id), {:delete_all_tickets, filter})

  @impl true
  def init(room_id) do
    # Process.flag(:trap_exit, true)
    Logger.info("Started new GameState GenServer with state: #{room_id}", ansi_color: :yellow)

    tasks = [
      Task.async(fn -> Rooms.get_room!(room_id) end),
      Task.async(fn -> Tickets.list_tickets(room_id) end)
    ]

    [room, tickets] = Task.await_many(tasks)

    state =
      %Game{room: room, tickets: tickets}
      |> count_tickets()
      |> set_active_ticket()
      |> get_state()

    {:ok, state}
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
      |> count_votes()
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
  def handle_cast(:next_ticket, %Game{state: :waiting_to_start} = state) do
    Logger.debug("Starting game in #{state.room.id}", ansi_color: :blue)

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
  def handle_cast({:add_ticket, %Ticket{} = ticket}, %Game{} = state) do
    Logger.debug("Added new ticket #{ticket.name} in #{state.room.id}", ansi_color: :blue)

    state =
      %Game{
        state
        | tickets: Enum.concat(state.tickets, [ticket]),
          total_tickets_not_started: state.total_tickets_not_started + 1,
          total_tickets: state.total_tickets + 1
      }
      |> set_active_ticket()
      |> get_state()

    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:edit_ticket, %Ticket{} = ticket}, %Game{} = state) do
    Logger.debug("Edited ticket #{ticket.name} in #{state.room.id}", ansi_color: :blue)

    index = Enum.find_index(state.tickets, &(&1.id == ticket.id))

    state =
      %Game{state | tickets: List.replace_at(state.tickets, index, ticket)}
      |> set_active_ticket()

    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_ticket, %Ticket{} = ticket}, %Game{} = state) do
    ticket = Enum.find(state.tickets, &(&1.id == ticket.id))
    Logger.debug("Deleting ticket #{ticket.name} in #{state.room.id}", ansi_color: :blue)

    state =
      %Game{state | tickets: List.delete(state.tickets, ticket)}
      |> count_tickets()
      |> set_active_ticket()
      |> get_state()

    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_all_tickets, "not_started"}, state) do
    Logger.debug("Deleting all not started tickets in #{state.room.id}", ansi_color: :blue)

    state =
      %Game{state | tickets: Enum.filter(state.tickets, &(&1.status != :not_started))}
      |> count_tickets()
      |> set_active_ticket()
      |> get_state()

    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_all_tickets, "completed"}, state) do
    Logger.debug("Deleting all completed tickets in #{state.room.id}", ansi_color: :blue)

    state =
      %Game{state | tickets: Enum.filter(state.tickets, &(&1.status != :completed))}
      |> count_tickets()
      |> set_active_ticket()
      |> get_state()

    broadcast_state!(state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_all_tickets, "total"}, state) do
    Logger.debug("Deleting all tickets in #{state.room.id}", ansi_color: :blue)

    state =
      %Game{state | tickets: %{}}
      |> count_tickets()
      |> set_active_ticket()
      |> get_state()

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
    %Game{
      state
      | total_votes:
          state.users |> Enum.count(fn {_, user} -> Map.has_key?(state.votes, user.id) end)
    }
  end

  defp count_tickets(%Game{} = state) do
    frequences = Enum.frequencies_by(state.tickets, & &1.status)

    %Game{
      state
      | total_tickets: Enum.count(state.tickets),
        total_tickets_not_started: Map.get(frequences, :not_started, 0),
        total_tickets_completed: Map.get(frequences, :completed, 0)
    }
  end

  defp get_state(%Game{active_ticket: nil} = state) do
    %Game{state | state: :game_over, votes: %{}, total_votes: 0}
  end

  defp get_state(%Game{state: :game_over, active_ticket: _ticket_} = state) do
    %Game{state | state: :waiting_to_start}
  end

  defp get_state(%Game{state: :voting, total_users: users, total_votes: votes} = state)
       when users == votes do
    %Game{state | state: :show_results}
  end

  defp get_state(%Game{} = state), do: state

  defp set_active_ticket(%Game{} = state) do
    %Game{state | active_ticket: Enum.find(state.tickets, &(&1.status == :not_started))}
  end

  defp process_name(room_id), do: {:via, Registry, {GameRegistry, room_id}}
end
