defmodule Badwithdates.Events.ReminderPreference do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reminder_preferences" do
    field :reminder_days, {:array, :integer}, default: [1, 7]
    field :enabled, :boolean, default: true
    field :notification_type, :string, default: "email"
    field :custom_message, :string
    belongs_to :event, Badwithdates.Events.Event

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reminder_preference, attrs) do
    reminder_preference
    |> cast(attrs, [:event_id, :reminder_days, :enabled, :notification_type, :custom_message])
    |> validate_required([:event_id, :reminder_days, :enabled, :notification_type])
    |> validate_inclusion(:notification_type, ["email", "sms", "push", "all"])
    |> validate_reminder_days()
    |> validate_length(:custom_message, max: 500)
  end

  defp validate_reminder_days(changeset) do
    case get_change(changeset, :reminder_days) do
      nil -> changeset
      days when is_list(days) ->
        if Enum.all?(days, &is_integer/1) and Enum.all?(days, &(&1 >= 0 and &1 <= 365)) do
          changeset
        else
          add_error(changeset, :reminder_days, "must be a list of integers between 0 and 365")
        end
      _ ->
        add_error(changeset, :reminder_days, "must be a list")
    end
  end

  def default_preferences do
    %{
      reminder_days: [1, 7],
      enabled: true,
      notification_type: "email",
      custom_message: nil
    }
  end
end
