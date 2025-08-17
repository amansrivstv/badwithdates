defmodule Badwithdates.Dashboard do
  @moduledoc """
  The Dashboard context for handling dashboard-related functionality.
  """

  import Ecto.Query, warn: false
  alias Badwithdates.Repo
  alias Badwithdates.Events.Event
  alias Badwithdates.Events.ReminderLog

  @doc """
  Gets upcoming events for a user within the specified number of days.
  Excludes today's events.
  """
  def get_upcoming_events(user_id, days \\ 30) do
    from_date = Date.utc_today()
    to_date = Date.add(from_date, days)

    from(e in Event,
      where: e.user_id == ^user_id,
      where: fragment("EXTRACT(month FROM ?)", e.date) >= ^from_date.month,
      where: fragment("EXTRACT(day FROM ?)", e.date) >= ^from_date.day,
      or_where: fragment("EXTRACT(month FROM ?)", e.date) > ^from_date.month,
      order_by: [
        asc: fragment("EXTRACT(month FROM ?)", e.date),
        asc: fragment("EXTRACT(day FROM ?)", e.date)
      ],
      limit: 10
    )
    |> Repo.all()
    |> Enum.filter(fn event ->
      next_date = Event.next_occurrence_date(event.date)
      # Exclude today's events from upcoming
      Date.compare(next_date, from_date) != :eq and Date.compare(next_date, to_date) != :gt
    end)
  end

  @doc """
  Gets today's events for a user.
  """
  def get_todays_events(user_id) do
    today = Date.utc_today()

    from(e in Event,
      where: e.user_id == ^user_id,
      where: fragment("EXTRACT(month FROM ?)", e.date) == ^today.month,
      where: fragment("EXTRACT(day FROM ?)", e.date) == ^today.day
    )
    |> Repo.all()
  end

  @doc """
  Gets monthly statistics for a user.
  """
  def get_monthly_stats(user_id, _year, month) do
    from(e in Event,
      where: e.user_id == ^user_id,
      where: fragment("EXTRACT(month FROM ?)", e.date) == ^month,
      select: {e.category, count(e.id)},
      group_by: e.category
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets yearly statistics for a user.
  """
  def get_yearly_stats(user_id, _year) do
    from(e in Event,
      where: e.user_id == ^user_id,
      select: {fragment("EXTRACT(month FROM ?)", e.date), count(e.id)},
      group_by: fragment("EXTRACT(month FROM ?)", e.date),
      order_by: fragment("EXTRACT(month FROM ?)", e.date)
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets category breakdown for a user.
  """
  def get_category_breakdown(user_id) do
    from(e in Event,
      where: e.user_id == ^user_id,
      select: {e.category, count(e.id)},
      group_by: e.category,
      order_by: [desc: count(e.id)]
    )
    |> Repo.all()
  end

  @doc """
  Gets priority breakdown for a user.
  """
  def get_priority_breakdown(user_id) do
    from(e in Event,
      where: e.user_id == ^user_id,
      select: {e.priority, count(e.id)},
      group_by: e.priority,
      order_by: e.priority
    )
    |> Repo.all()
  end

  @doc """
  Gets reminder statistics for a user.
  """
  def get_reminder_stats(user_id, days \\ 30) do
    from_date = Date.utc_today()
    to_date = Date.add(from_date, days)

    from(r in ReminderLog,
      join: e in Event, on: r.event_id == e.id,
      where: e.user_id == ^user_id,
      where: fragment("DATE(?)", r.sent_at) >= ^from_date,
      where: fragment("DATE(?)", r.sent_at) <= ^to_date,
      select: {r.reminder_type, count(r.id)},
      group_by: r.reminder_type
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Gets overdue events for a user.
  """
  def get_overdue_events(user_id) do
    from(e in Event,
      where: e.user_id == ^user_id,
      where: fragment("EXTRACT(month FROM ?)", e.date) < ^Date.utc_today().month,
      or_where: fragment("EXTRACT(month FROM ?)", e.date) == ^Date.utc_today().month and fragment("EXTRACT(day FROM ?)", e.date) < ^Date.utc_today().day,
      order_by: [
        desc: fragment("EXTRACT(month FROM ?)", e.date),
        desc: fragment("EXTRACT(day FROM ?)", e.date)
      ],
      limit: 5
    )
    |> Repo.all()
  end

  @doc """
  Gets events by tag for a user.
  """
  def get_events_by_tag(user_id, tag) do
    from(e in Event,
      where: e.user_id == ^user_id,
      where: ^tag in e.tags,
      order_by: [asc: e.date]
    )
    |> Repo.all()
  end

  @doc """
  Gets all unique tags for a user.
  """
  def get_user_tags(user_id) do
    from(e in Event,
      where: e.user_id == ^user_id,
      select: fragment("unnest(?)", e.tags),
      distinct: true
    )
    |> Repo.all()
    |> Enum.sort()
  end

  @doc """
  Gets dashboard summary for a user.
  """
  def get_dashboard_summary(user_id) do
    %{
      total_events: count_total_events(user_id),
      todays_events: length(get_todays_events(user_id)),
      upcoming_events: length(get_upcoming_events(user_id, 7)),
      overdue_events: length(get_overdue_events(user_id)),
      category_breakdown: get_category_breakdown(user_id),
      priority_breakdown: get_priority_breakdown(user_id),
      reminder_stats: get_reminder_stats(user_id, 7)
    }
  end

  defp count_total_events(user_id) do
    from(e in Event, where: e.user_id == ^user_id, select: count(e.id))
    |> Repo.one()
  end
end
