defmodule QuickPoint.Repo.Migrations.CreateTickets do
  use Ecto.Migration

  def change do
    create table(:tickets) do
      add :name, :string
      add :description, :string
      add :effort, :integer
      add :status, :string
      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:tickets, [:room_id])
  end
end
