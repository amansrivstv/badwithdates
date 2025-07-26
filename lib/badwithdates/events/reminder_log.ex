defmodule Badwithdates.Events.ReminderLog do
  use Ecto.Schema

  schema "reminder_logs" do
    field :year, :integer
    field :reminder_type, Ecto.Enum, values: [:seven_day, :one_day]
    field :sent_at, :utc_datetime_usec
    belongs_to :event, Badwithdates.Events.Event

    timestamps()
  end
end
