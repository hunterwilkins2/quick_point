defmodule QuickPoint.Game.Game do
  @enforce_keys [:room]
  defstruct state: :game_over, room: nil, users: %{}, votes: %{}, total_users: 0, total_votes: 0
end
