defmodule Badwithdates.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string
    field :date, :date
    field :category, :string
    field :description, :string
    field :tags, {:array, :string}, default: []
    field :photo_url, :string
    field :is_public, :boolean, default: false
    field :priority, :integer, default: 1
    field :notes, :string
    field :location, :string
    field :recurring, :boolean, default: true
    belongs_to :user, Badwithdates.Accounts.User

    # Associations
    has_one :reminder_preference, Badwithdates.Events.ReminderPreference
    has_many :event_shares, Badwithdates.Events.EventShare
    has_many :audit_logs, Badwithdates.Events.AuditLog, foreign_key: :resource_id, where: [resource_type: "event"]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, user_scope) do
    event
    |> cast(attrs, [:title, :date, :category, :description, :tags, :photo_url, :is_public, :priority, :notes, :location, :recurring])
    |> validate_required([:title, :date, :category])
    |> validate_inclusion(:category, valid_categories())
    |> validate_inclusion(:priority, 1..5)
    |> validate_length(:title, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_length(:notes, max: 5000)
    |> validate_length(:location, max: 255)
    |> validate_tags()
    |> put_change(:user_id, user_scope.user.id)
  end

  defp valid_categories do
    [
      "birthday", "anniversary", "graduation", "retirement",
      "wedding", "holiday", "custom", "work", "personal"
    ]
  end

  defp validate_tags(changeset) do
    case get_change(changeset, :tags) do
      nil -> changeset
      tags when is_list(tags) ->
        if Enum.all?(tags, &is_binary/1) and length(tags) <= 10 do
          changeset
        else
          add_error(changeset, :tags, "must be a list of up to 10 strings")
        end
      _ ->
        add_error(changeset, :tags, "must be a list")
    end
  end

  # Helper functions for event display
  def days_until_event(%__MODULE__{date: date}) do
    today = Date.utc_today()
    next_occurrence = next_occurrence_date(date)
    Date.diff(next_occurrence, today)
  end

  def next_occurrence_date(%Date{} = date) do
    today = Date.utc_today()
    year = today.year

    # Calculate next occurrence
    next_date = %Date{date | year: year}

    cond do
      Date.compare(next_date, today) == :lt ->
        %Date{date | year: year + 1}
      true ->
        next_date
    end
  end

  def is_upcoming?(event, days \\ 30) do
    days_until = days_until_event(event)
    days_until >= 0 and days_until <= days
  end

  def is_today?(event) do
    today = Date.utc_today()
    event_date = next_occurrence_date(event.date)
    Date.compare(today, event_date) == :eq
  end

  def is_overdue?(event) do
    days_until_event(event) < 0
  end
end
