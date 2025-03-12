defmodule QuickPoint.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tickets" do
    field :name, :string

    field :status, Ecto.Enum,
      values: [:not_started, :in_progress, :completed],
      default: :not_started

    field :description, :string
    field :effort, :integer

    belongs_to :room, QuickPoint.Rooms.Room, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:name, :description, :effort, :status])
    |> validate_required([:name, :status])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_length(:description, max: 500)
    |> validate_number(:effort, greater_than_or_equal_to: 0, less_than: 100)
    |> assoc_constraint(:room)
  end
end
