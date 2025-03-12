defmodule QuickPoint.Repo.Migrations.CreateRoomRoles do
  use Ecto.Migration

  def change do
    create table(:room_roles) do
      add :role, :string
      add :user_id, references(:users, on_delete: :delete_all)
      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:room_roles, [:user_id])
    create index(:room_roles, [:room_id])
  end
end
