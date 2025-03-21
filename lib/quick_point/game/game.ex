defmodule QuickPoint.Game.Game do
  defstruct state: :game_over, users: %{}, votes: %{}, total_users: 0, total_votes: 0
end
