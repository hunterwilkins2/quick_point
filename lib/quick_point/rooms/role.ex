defmodule QuickPoint.Rooms.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "room_roles" do
    field :role, Ecto.Enum, values: [:moderator, :observer, :player]

    belongs_to :user, QuickPoint.Accounts.User
    belongs_to :room, QuickPoint.Rooms.Room, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> assoc_constraint(:user)
    |> assoc_constraint(:room)
  end
end
