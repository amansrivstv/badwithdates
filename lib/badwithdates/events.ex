defmodule Badwithdates.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias Badwithdates.Repo

  alias Badwithdates.Events.{Event, ReminderPreference, EventShare, UserGroup, GroupMember, AuditLog}
  alias Badwithdates.Accounts.Scope
  alias Elixlsx.{Workbook, Sheet}

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
  Returns the list of events with filters.
  """
  def list_events(%Scope{} = scope, filters \\ %{}) do
    Event
    |> filter_by_user(scope.user.id)
    |> filter_by_category(filters[:category])
    |> filter_by_priority(filters[:priority])
    |> filter_by_tags(filters[:tags])
    |> filter_by_date_range(filters[:start_date], filters[:end_date])
    |> filter_by_search(filters[:search])
    |> order_by([e], [asc: e.date])
    |> Repo.all()
  end

  defp filter_by_user(query, user_id) do
    from(e in query, where: e.user_id == ^user_id)
  end

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, category) do
    from(e in query, where: e.category == ^category)
  end

  defp filter_by_priority(query, nil), do: query
  defp filter_by_priority(query, priority) do
    from(e in query, where: e.priority == ^priority)
  end

  defp filter_by_tags(query, nil), do: query
  defp filter_by_tags(query, tags) when is_list(tags) do
    from(e in query, where: fragment("? && ?", e.tags, ^tags))
  end

  defp filter_by_date_range(query, nil, nil), do: query
  defp filter_by_date_range(query, start_date, nil) do
    from(e in query, where: e.date >= ^start_date)
  end
  defp filter_by_date_range(query, nil, end_date) do
    from(e in query, where: e.date <= ^end_date)
  end
  defp filter_by_date_range(query, start_date, end_date) do
    from(e in query, where: e.date >= ^start_date and e.date <= ^end_date)
  end

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, search_term) when is_binary(search_term) do
    search_term = "%#{search_term}%"
    from(e in query,
      where: ilike(e.title, ^search_term) or
             ilike(e.description, ^search_term) or
             ilike(e.notes, ^search_term) or
             ilike(e.location, ^search_term) or
             fragment("? && ?", e.tags, ^[search_term])
    )
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
    |> Repo.preload([:reminder_preference, :event_shares])
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
    Repo.transaction(fn ->
      with {:ok, event = %Event{}} <-
             %Event{}
             |> Event.changeset(attrs, scope)
             |> Repo.insert(),
           {:ok, _preference} <-
             create_default_reminder_preferences(event) do

        # Log the action
        AuditLog.log_action(scope.user.id, "create", "event", event.id, %{title: event.title})

        broadcast(scope, {:created, event})
        event
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
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

      # Log the action
      AuditLog.log_action(scope.user.id, "update", "event", event.id, %{title: event.title})

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

      # Log the action
      AuditLog.log_action(scope.user.id, "delete", "event", event.id, %{title: event.title})

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

  # Reminder Preferences
  def get_reminder_preference(event_id) do
    Repo.get_by(ReminderPreference, event_id: event_id)
  end

  def create_reminder_preference(attrs) do
    %ReminderPreference{}
    |> ReminderPreference.changeset(attrs)
    |> Repo.insert()
  end

  def update_reminder_preference(%ReminderPreference{} = preference, attrs) do
    preference
    |> ReminderPreference.changeset(attrs)
    |> Repo.update()
  end

  def create_default_reminder_preferences(%Event{} = event) do
    default_prefs = ReminderPreference.default_preferences()
    create_reminder_preference(Map.put(default_prefs, :event_id, event.id))
  end

  def create_default_reminder_preferences(event_id) when is_integer(event_id) do
    default_prefs = ReminderPreference.default_preferences()
    create_reminder_preference(Map.put(default_prefs, :event_id, event_id))
  end

  # Event Sharing
  def share_event(%Scope{} = scope, %Event{} = event, share_params) do
    true = event.user_id == scope.user.id

    share_attrs = %{
      event_id: event.id,
      shared_by_user_id: scope.user.id,
      share_token: EventShare.generate_share_token(),
      expires_at: DateTime.add(DateTime.utc_now(), 7, :day)
    }
    |> Map.merge(share_params)

    %EventShare{}
    |> EventShare.changeset(share_attrs)
    |> Repo.insert()
  end

  def get_shared_event(share_token) do
    Repo.get_by(EventShare, share_token: share_token)
    |> Repo.preload([:event, :shared_by_user])
  end

  def mark_share_as_viewed(%EventShare{} = share) do
    share
    |> EventShare.changeset(%{viewed_at: DateTime.utc_now()})
    |> Repo.update()
  end

  # User Groups
  def create_user_group(%Scope{} = scope, attrs) do
    attrs = Map.put(attrs, :created_by_user_id, scope.user.id)

    Repo.transaction(fn ->
      with {:ok, group = %UserGroup{}} <-
             %UserGroup{}
             |> UserGroup.changeset(attrs)
             |> Repo.insert() do

        # Add creator as admin member
        create_group_member(%{
          group_id: group.id,
          user_id: scope.user.id,
          role: "admin"
        })

        group
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def get_user_groups(%Scope{} = scope) do
    from(g in UserGroup,
      left_join: gm in GroupMember, on: g.id == gm.group_id,
      where: g.created_by_user_id == ^scope.user.id or gm.user_id == ^scope.user.id,
      distinct: g.id,
      preload: [:group_members, :members]
    )
    |> Repo.all()
  end

  def create_group_member(attrs) do
    %GroupMember{}
    |> GroupMember.changeset(attrs)
    |> Repo.insert()
  end

  # Search functionality
  def search_events(%Scope{} = scope, query) do
    search_term = "%#{query}%"

    from(e in Event,
      where: e.user_id == ^scope.user.id,
      where: ilike(e.title, ^search_term) or
             ilike(e.description, ^search_term) or
             ilike(e.notes, ^search_term) or
             ilike(e.location, ^search_term) or
             fragment("? && ?", e.tags, ^[query]),
      order_by: [asc: e.date]
    )
    |> Repo.all()
  end

  # Bulk operations
  def bulk_update_events(%Scope{} = scope, event_ids, attrs) do
    from(e in Event,
      where: e.id in ^event_ids and e.user_id == ^scope.user.id
    )
    |> Repo.update_all(set: attrs)
  end

  def bulk_delete_events(%Scope{} = scope, event_ids) do
    from(e in Event,
      where: e.id in ^event_ids and e.user_id == ^scope.user.id
    )
    |> Repo.delete_all()
  end

  # Existing functions with updates
  def get_events_by_date_range(start_date, end_date, user_id) do
    from(e in Event,
      where: e.date >= ^start_date and e.date <= ^end_date and e.user_id == ^user_id,
      order_by: [asc: e.date]
    )
    |> Repo.all()
  end

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

  def export_events_to_excel(%Scope{} = scope) do
    events = list_events(scope)
    cleaned_data =
      events
      |> Enum.map(fn event ->
        [
          event.title,
          Date.to_string(event.date),
          event.category,
          event.description || "",
          Enum.join(event.tags, ", "),
          event.priority,
          event.location || "",
          event.notes || ""
        ]
      end)

    # Create Excel workbook
    workbook = %Workbook{
      sheets: [
        %Sheet{
          name: "Events",
          rows:
            [
              # Header row
              ["Title", "Date", "Category", "Description", "Tags", "Priority", "Location", "Notes"]
            ] ++ cleaned_data
        }
      ]
    }
    {:ok, {_filename, binary_data}} = Elixlsx.write_to_memory(workbook, "events.xlsx")
    binary_data
  end

  # Import events from Excel file
  def import_events_from_excel(%Scope{} = scope, file_path) do
    try do
      # Extract data from Excel file
      {:ok, data} = Xlsxir.extract(file_path, 0)

      # Get all rows except header
      rows = Xlsxir.get_list(data)
      [_header | data_rows] = rows
      # Close the extraction process
      Xlsxir.close(data)

      # Process each row
      results =
        Enum.map(data_rows, fn row ->
          case parse_enhanced_excel_row(row) do
            {:ok, event_attrs} ->
              create_event(scope, event_attrs)

            {:error, reason} ->
              {:error, reason}
          end
        end)

      # Count successes and failures
      successes = Enum.count(results, fn {status, _} -> status == :ok end)
      failures = Enum.count(results, fn {status, _} -> status == :error end)

      {:ok, %{successes: successes, failures: failures, details: results}}
    rescue
      error ->
        {:error, "Failed to process Excel file: #{inspect(error)}"}
    end
  end

  # Parse a single Excel row into event attributes (enhanced version)
  defp parse_enhanced_excel_row([title, date, category_str, description, tags_str, priority_str, location, notes]) do
    with {:ok, category} <- parse_category(category_str),
         {:ok, priority} <- parse_priority(priority_str),
         {:ok, tags} <- parse_tags(tags_str) do
      {:ok,
       %{
         title: to_string(title),
         date: date,
         category: category,
         description: if(description && description != "", do: to_string(description), else: nil),
         tags: tags,
         priority: priority,
         location: if(location && location != "", do: to_string(location), else: nil),
         notes: if(notes && notes != "", do: to_string(notes), else: nil)
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_enhanced_excel_row(row) do
    {:error, "Invalid row format: expected 8 columns, got #{length(row)}"}
  end

  # Parse priority
  defp parse_priority(priority_str) when is_binary(priority_str) do
    case Integer.parse(priority_str) do
      {priority, _} when priority >= 1 and priority <= 5 -> {:ok, priority}
      _ -> {:error, "Invalid priority: #{priority_str}. Must be between 1 and 5"}
    end
  rescue
    ArgumentError -> {:error, "Invalid priority: #{priority_str}"}
  end

  defp parse_priority(priority_int) when is_integer(priority_int) and priority_int >= 1 and priority_int <= 5 do
    {:ok, priority_int}
  end

  defp parse_priority(_), do: {:ok, 1} # Default priority

  # Parse tags
  defp parse_tags(tags_str) when is_binary(tags_str) do
    tags = tags_str
           |> String.split(",")
           |> Enum.map(&String.trim/1)
           |> Enum.filter(&(&1 != ""))

    if length(tags) <= 10 do
      {:ok, tags}
    else
      {:error, "Too many tags: #{length(tags)}. Maximum is 10"}
    end
  end

  defp parse_tags(tags_list) when is_list(tags_list) do
    {:ok, tags_list}
  end

  defp parse_tags(_), do: {:ok, []}

  # Parse category
  defp parse_category(category_str) when is_binary(category_str) do
    category = String.downcase(category_str)

    if category in ["birthday", "anniversary", "graduation", "retirement", "wedding", "holiday", "custom", "work", "personal"] do
      {:ok, category}
    else
      {:error, "Invalid category: #{category_str}"}
    end
  rescue
    ArgumentError ->
      {:error, "Invalid category: #{category_str}"}
  end

  defp parse_category(category_atom) when is_atom(category_atom) do
    category_str = Atom.to_string(category_atom)
    parse_category(category_str)
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
    from(r in Badwithdates.Events.ReminderLog,
      where: r.event_id == ^event_id,
      where: r.year == ^year,
      where: r.reminder_type == ^reminder_type
    )
    |> Repo.exists?()
  end

  # Record that a reminder was sent
  def record_reminder_sent(event_id, year, reminder_type) do
    %Badwithdates.Events.ReminderLog{
      event_id: event_id,
      year: year,
      reminder_type: reminder_type,
      sent_at: DateTime.utc_now()
    }
    |> Repo.insert()
  end
end
