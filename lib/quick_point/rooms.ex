defmodule QuickPoint.Rooms do
  @moduledoc """
  The Rooms context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias QuickPoint.Repo

  alias QuickPoint.Rooms.Room
  alias QuickPoint.Rooms.Role
  alias QuickPoint.Tickets.Ticket
  alias QuickPoint.Accounts.User

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

  """
  def list_rooms(user) do
    moderator_query =
      from r in Room,
        join: m in Role,
        on: m.room_id == r.id and m.user_id == ^user.id and m.role == :moderator

    player_query =
      from r in Room,
        as: :room,
        join: m in Role,
        on: m.room_id == r.id and m.user_id == ^user.id,
        where:
          not exists(
            from p in Role,
              where:
                parent_as(:room).id == p.room_id and p.user_id == ^user.id and
                  p.role == :moderator
          )

    rooms_owned = Repo.all(moderator_query)
    rooms_visited = Repo.all(player_query)

    %{moderator: rooms_owned, visited: rooms_visited}
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

  def get_room_and_tickets!(id) do
    query =
      from r in Room,
        where: r.id == ^id,
        left_join: t in Ticket,
        on: t.room_id == r.id,
        group_by: [r.id],
        select: %{
          room: r,
          total_tickets: count(t.id),
          active_tickets:
            sum(
              fragment("""
              case when t1."status" = 'not_started' then 1 else 0 end
              """)
            ),
          completed_tickets:
            sum(
              fragment("""
              case when t1."status" = 'completed' then 1 else 0 end
              """)
            )
        }

    Repo.one(query)
  end

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
  def update_room(%User{} = user, %Room{} = room, attrs) do
    case is_moderator?(user, room) do
      true ->
        room
        |> Room.changeset(attrs)
        |> Repo.update()

      false ->
        {:error, :unauthorized_action}
    end
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%User{} = user, %Room{} = room) do
    case is_moderator?(user, room) do
      true ->
        Repo.delete(room)

      false ->
        {:error, :unauthorized_action}
    end
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

  def list_or_create_roles(%User{} = user, %Room{} = room) do
    query =
      from r in Role,
        where: [user_id: ^user.id, room_id: ^room.id]

    case Repo.all(query) do
      [] ->
        player_role =
          Repo.insert!(Role.changeset(%Role{user: user, room: room}, %{role: :player}))

        [player_role]

      roles ->
        roles
    end
  end

  def is_moderator?(%User{} = user, %Room{} = room) do
    query =
      from Role,
        where: [user_id: ^user.id, room_id: ^room.id, role: :moderator]

    Repo.exists?(query)
  end
end
