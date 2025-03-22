defmodule QuickPoint.Game.Game do
  @enforce_keys [:room, :tickets]
  defstruct state: :game_over,
            room: nil,
            users: %{},
            votes: %{},
            total_users: 0,
            total_votes: 0,
            active_ticket: nil,
            tickets: [],
            total_tickets_not_started: 0,
            total_tickets_completed: 0,
            total_tickets: 0
end
