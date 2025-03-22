defmodule QuickPoint.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias QuickPoint.Repo

  alias QuickPoint.Tickets.Ticket
  alias QuickPoint.Rooms.Room
  alias QuickPoint.Rooms
  alias QuickPoint.Accounts.User

  @doc """
  Returns the list of tickets.

  ## Examples

      iex> list_tickets()
      [%Ticket{}, ...]

  """
  def list_tickets(%Room{} = room) do
    query = from t in Ticket, where: t.room_id == ^room.id

    Repo.all(query)
  end

  def list_tickets(room_id) do
    query = from t in Ticket, where: t.room_id == ^room_id

    Repo.all(query)
  end

  @doc """
  Gets a single ticket.

  Raises `Ecto.NoResultsError` if the Ticket does not exist.

  ## Examples

      iex> get_ticket!(123)
      %Ticket{}

      iex> get_ticket!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ticket!(id), do: Repo.get!(Ticket, id)

  def get_active(room_id) do
    query =
      from Ticket,
        where: [status: :not_started, room_id: ^room_id],
        order_by: [asc: :id],
        limit: 1

    Repo.one(query)
  end

  def filter(room, "not_started") do
    query =
      from Ticket,
        where: [status: :not_started, room_id: ^room.id],
        order_by: [asc: :id]

    Repo.all(query)
  end

  def filter(room, "completed") do
    query =
      from Ticket,
        where: [status: :completed, room_id: ^room.id],
        order_by: [desc: :updated_at]

    Repo.all(query)
  end

  def filter(room, "total") do
    query =
      from Ticket,
        where: [room_id: ^room.id],
        order_by: [asc: :id]

    Repo.all(query)
  end

  @doc """
  Creates a ticket.

  ## Examples

      iex> create_ticket(%{field: value})
      {:ok, %Ticket{}}

      iex> create_ticket(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ticket(%User{} = user, %Room{} = room, attrs \\ %{}) do
    case Rooms.is_moderator?(user, room) do
      true ->
        %Ticket{room: room}
        |> Ticket.changeset(attrs)
        |> Repo.insert()

      false ->
        {:error, :unauthorized_action}
    end
  end

  @doc """
  Updates a ticket.

  ## Examples

      iex> update_ticket(ticket, %{field: new_value})
      {:ok, %Ticket{}}

      iex> update_ticket(ticket, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ticket(%User{} = user, %Room{} = room, %Ticket{} = ticket, attrs) do
    case Rooms.is_moderator?(user, room) do
      true ->
        ticket
        |> Ticket.changeset(attrs)
        |> Repo.update()

      false ->
        {:error, :unauthorized_action}
    end
  end

  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ticket.

  ## Examples

      iex> delete_ticket(ticket)
      {:ok, %Ticket{}}

      iex> delete_ticket(ticket)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ticket(%User{} = user, %Room{} = room, %Ticket{} = ticket) do
    case Rooms.is_moderator?(user, room) do
      true ->
        Repo.delete(ticket)

      false ->
        {:error, :unauthorized_action}
    end
  end

  def delete_where(%User{} = user, %Room{} = room, filter) do
    case Rooms.is_moderator?(user, room) do
      true ->
        delete_tickets(room, filter)

      false ->
        {:error, :unauthorized_action}
    end
  end

  defp delete_tickets(%Room{} = room, "not_started") do
    query =
      from Ticket,
        where: [status: :not_started, room_id: ^room.id]

    Repo.delete_all(query)
  end

  defp delete_tickets(%Room{} = room, "completed") do
    query =
      from Ticket,
        where: [status: :completed, room_id: ^room.id]

    Repo.delete_all(query)
  end

  defp delete_tickets(%Room{} = room, "total") do
    query =
      from Ticket,
        where: [room_id: ^room.id]

    Repo.delete_all(query)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ticket changes.

  ## Examples

      iex> change_ticket(ticket)
      %Ecto.Changeset{data: %Ticket{}}

  """
  def change_ticket(%Ticket{} = ticket, attrs \\ %{}) do
    Ticket.changeset(ticket, attrs)
  end
end
