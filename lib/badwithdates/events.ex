defmodule Badwithdates.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias Badwithdates.Repo

  alias Badwithdates.Events.Event
  alias Badwithdates.Accounts.Scope
  alias Badwithdates.Events.ReminderLog

  @doc """
  Subscribes to scoped notifications about any event changes.

  The broadcasted messages match the pattern:

    * {:created, %Event{}}
    * {:updated, %Event{}}
    * {:deleted, %Event{}}

  """
  def subscribe_events(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(Badwithdates.PubSub, "user:#{key}:events")
  end

  defp broadcast(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(Badwithdates.PubSub, "user:#{key}:events", message)
  end

  @doc """
  Returns the list of events.

  ## Examples

      iex> list_events(scope)
      [%Event{}, ...]

  """
  def list_events(%Scope{} = scope) do
    Repo.all_by(Event, user_id: scope.user.id)
  end

  @doc """
  Gets a single event.

  Raises `Ecto.NoResultsError` if the Event does not exist.

  ## Examples

      iex> get_event!(123)
      %Event{}

      iex> get_event!(456)
      ** (Ecto.NoResultsError)

  """
  def get_event!(%Scope{} = scope, id) do
    Repo.get_by!(Event, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a event.

  ## Examples

      iex> create_event(%{field: value})
      {:ok, %Event{}}

      iex> create_event(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_event(%Scope{} = scope, attrs) do
    with {:ok, event = %Event{}} <-
           %Event{}
           |> Event.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast(scope, {:created, event})
      {:ok, event}
    end
  end

  @doc """
  Updates a event.

  ## Examples

      iex> update_event(event, %{field: new_value})
      {:ok, %Event{}}

      iex> update_event(event, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_event(%Scope{} = scope, %Event{} = event, attrs) do
    true = event.user_id == scope.user.id

    with {:ok, event = %Event{}} <-
           event
           |> Event.changeset(attrs, scope)
           |> Repo.update() do
      broadcast(scope, {:updated, event})
      {:ok, event}
    end
  end

  @doc """
  Deletes a event.

  ## Examples

      iex> delete_event(event)
      {:ok, %Event{}}

      iex> delete_event(event)
      {:error, %Ecto.Changeset{}}

  """
  def delete_event(%Scope{} = scope, %Event{} = event) do
    true = event.user_id == scope.user.id

    with {:ok, event = %Event{}} <-
           Repo.delete(event) do
      broadcast(scope, {:deleted, event})
      {:ok, event}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event changes.

  ## Examples

      iex> change_event(event)
      %Ecto.Changeset{data: %Event{}}

  """
  def change_event(%Scope{} = scope, %Event{} = event, attrs \\ %{}) do
    true = event.user_id == scope.user.id

    Event.changeset(event, attrs, scope)
  end

  def get_events_by_date_range(start_date, end_date, user_id) do
    from(e in Event,
      where: e.date >= ^start_date and e.date <= ^end_date and e.user_id == ^user_id,
      order_by: [asc: e.date]
    )
    |> Repo.all()
  end

  # for admin view
  def get_events_by_date_range(start_date, end_date) do
    from(e in Event,
      where: e.date >= ^start_date and e.date <= ^end_date,
      order_by: [asc: e.date]
    )
    |> Repo.all()
  end

  def get_events_by_date_range_ignore_year(start_date, end_date, user_id) do
    start_month = start_date.month
    start_day = start_date.day
    end_month = end_date.month
    end_day = end_date.day

    query = from(e in Event, where: e.user_id == ^user_id)

    # Handle year-spanning ranges (like Nov-Feb)
    query =
      if start_month <= end_month do
        # Same calendar year range
        from(e in query,
          where:
            (fragment("EXTRACT(month FROM ?)", e.date) > ^start_month and
               fragment("EXTRACT(month FROM ?)", e.date) < ^end_month) or
              (fragment("EXTRACT(month FROM ?)", e.date) == ^start_month and
                 fragment("EXTRACT(day FROM ?)", e.date) >= ^start_day) or
              (fragment("EXTRACT(month FROM ?)", e.date) == ^end_month and
                 fragment("EXTRACT(day FROM ?)", e.date) <= ^end_day)
        )
      else
        # Cross-year range (e.g., Nov 15 to Feb 28)
        from(e in query,
          where:
            fragment("EXTRACT(month FROM ?)", e.date) > ^start_month or
              fragment("EXTRACT(month FROM ?)", e.date) < ^end_month or
              (fragment("EXTRACT(month FROM ?)", e.date) == ^start_month and
                 fragment("EXTRACT(day FROM ?)", e.date) >= ^start_day) or
              (fragment("EXTRACT(month FROM ?)", e.date) == ^end_month and
                 fragment("EXTRACT(day FROM ?)", e.date) <= ^end_day)
        )
      end

    query
    |> order_by([e],
      asc: fragment("EXTRACT(month FROM ?)", e.date),
      asc: fragment("EXTRACT(day FROM ?)", e.date)
    )
    |> Repo.all()
  end
  def get_events_for_month_day(month, day) do
    from(e in Event,
      where: fragment("EXTRACT(month FROM ?)", e.date) == ^month,
      where: fragment("EXTRACT(day FROM ?)", e.date) == ^day,
      preload: [:user]
    )
    |> Repo.all()
  end

  # Check if a reminder was already sent
  def reminder_already_sent?(event_id, year, reminder_type) do
    from(r in ReminderLog,
      where: r.event_id == ^event_id,
      where: r.year == ^year,
      where: r.reminder_type == ^reminder_type
    )
    |> Repo.exists?()
  end

  # Record that a reminder was sent
  def record_reminder_sent(event_id, year, reminder_type) do
    %ReminderLog{
      event_id: event_id,
      year: year,
      reminder_type: reminder_type,
      sent_at: DateTime.utc_now()
    }
    |> Repo.insert()
  end
end
