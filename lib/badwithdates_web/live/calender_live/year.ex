# lib/your_app_web/live/calendar_live.ex
defmodule BadwithdatesWeb.CalendarLive.Year do
  use BadwithdatesWeb, :live_view
  alias Badwithdates.Events

  @impl true
  def mount(_params, _session, socket) do
    current_year = Date.utc_today().year

    socket =
      socket
      |> assign(:selected_year, current_year)
      |> assign(:events, [])
      |> load_events()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    year = case Map.get(params, "year") do
      nil -> socket.assigns.selected_year
      year_str -> String.to_integer(year_str)
    end

    socket =
      socket
      |> assign(:selected_year, year)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("year_selected", %{"year" => year}, socket) do
    year = String.to_integer(year)
    {:noreply, push_patch(socket, to: ~p"/calendar/#{year}")}
  end

  defp load_events(socket) do
    year = socket.assigns.selected_year
    start_date = Date.new!(year, 1, 1)
    end_date = Date.new!(year, 12, 31)

    # Get current user from current_scope
    current_user = socket.assigns.current_scope.user

    # Get events for the current user and date range
    events = Events.get_events_by_date_range_ignore_year(start_date, end_date, current_user.id)
    # Group events by date for easier lookup
    events_by_date =
      events
      |> Enum.group_by(fn event ->
        event.date
      end)

    # Generate calendar data for all months
    calendar_months = for month <- 1..12 do
      %{
        month: month,
        days: generate_calendar_days(year, month, events_by_date)
      }
    end

    socket
    |> assign(:events_by_date, events_by_date)
    |> assign(:calendar_months, calendar_months)
  end

  # defp get_events_for_date(events_by_date, date) do
  #   Map.get(events_by_date, date, [])
  # end

  defp get_events_for_date_ignore_year(events_by_date, date) do
    # Get events that match the month and day, regardless of year
    events_by_date
    |> Enum.filter(fn {event_date, _events} ->
      event_date.month == date.month and event_date.day == date.day
    end)
    |> Enum.flat_map(fn {_date, events} -> events end)
  end

  defp has_birthday?(events) do
    Enum.any?(events, fn event -> event.category == :birthday end)
  end

  defp has_anniversary?(events) do
    Enum.any?(events, fn event -> event.category == :anniversary end)
  end

  def month_name(month) do
    case month do
      1 -> "January"
      2 -> "February"
      3 -> "March"
      4 -> "April"
      5 -> "May"
      6 -> "June"
      7 -> "July"
      8 -> "August"
      9 -> "September"
      10 -> "October"
      11 -> "November"
      12 -> "December"
    end
  end

  defp days_in_month(year, month) do
    Date.days_in_month(Date.new!(year, month, 1))
  end

  defp first_day_of_month_weekday(year, month) do
    Date.day_of_week(Date.new!(year, month, 1))
  end

  defp generate_calendar_days(year, month, events_by_date) do
    days_in_month = days_in_month(year, month)
    first_weekday = first_day_of_month_weekday(year, month)

    # Empty cells for days before the first day of the month
    empty_cells = for _ <- 1..(first_weekday - 1), do: nil

    # Days of the month
    month_days = for day <- 1..days_in_month do
      date = Date.new!(year, month, day)
      events = get_events_for_date_ignore_year(events_by_date, date)
      %{
        day: day,
        date: date,
        events: events,
        has_birthday: has_birthday?(events),
        has_anniversary: has_anniversary?(events)
      }
    end

    empty_cells ++ month_days
  end
end
