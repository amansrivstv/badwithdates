defmodule Badwithdates.Repo.Migrations.FixReminderLogDatetimeColumn do
  use Ecto.Migration

  def up do
    # Change the column type to support microseconds
    alter table(:reminder_logs) do
      modify :sent_at, :utc_datetime_usec
    end
  end

  def down do
    # Revert back to the original type (will truncate microseconds)
    alter table(:reminder_logs) do
      modify :sent_at, :utc_datetime
    end
  end
end
