defmodule Badwithdates.Repo.Migrations.CreateReminderLogsTable do
  use Ecto.Migration

  def change do
    create table(:reminder_logs) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :reminder_type, :string, null: false
      add :sent_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:reminder_logs, [:event_id])
    create unique_index(:reminder_logs, [:event_id, :year, :reminder_type])
  end
end
