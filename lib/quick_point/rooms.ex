defmodule QuickPoint.Rooms do
  @moduledoc """
  The Rooms context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias QuickPoint.Repo

  alias QuickPoint.Rooms.Room
  alias QuickPoint.Rooms.Role

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

  """
  def list_rooms(user) do
    query =
      from r in Room,
        join: m in Role,
        on: m.room_id == r.id and m.user_id == ^user.id and m.role == :moderator

    Repo.all(query)
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(123)
      %Room{}

      iex> get_room!(456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{field: value})
      {:ok, %Room{}}

      iex> create_room(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(user, attrs \\ %{}) do
    result =
      Multi.new()
      |> Multi.insert(:room, Room.changeset(%Room{}, attrs))
      |> Multi.merge(fn %{room: room} ->
        Multi.new()
        |> Multi.insert(
          :moderator_role,
          Role.changeset(%Role{user: user, room: room}, %{role: :moderator})
        )
        |> Multi.insert(
          :player_role,
          Role.changeset(%Role{user: user, room: room}, %{role: :player})
        )
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{room: room}} ->
        {:ok, room}

      {:error, :room, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end
end
