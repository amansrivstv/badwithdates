# lib/your_app_web/live/calendar_live.ex
defmodule BadwithdatesWeb.CalendarLive.Year do
  use BadwithdatesWeb, :live_view
  alias Badwithdates.Events

  @impl true
  def mount(_params, _session, socket) do
    current_date = Date.utc_today()
    current_year = current_date.year
    current_month = current_date.month

    socket =
      socket
      |> assign(:selected_year, current_year)
      |> assign(:selected_month, current_month)
      |> assign(:view_mode, "2month") # Default to 2-month view
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

    month = case Map.get(params, "month") do
      nil -> socket.assigns.selected_month
      month_str -> String.to_integer(month_str)
    end

    view_mode = Map.get(params, "view", socket.assigns.view_mode)

    socket =
      socket
      |> assign(:selected_year, year)
      |> assign(:selected_month, month)
      |> assign(:view_mode, view_mode)
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("year_selected", %{"year" => year}, socket) do
    year = String.to_integer(year)
    {:noreply, push_patch(socket, to: ~p"/calendar/#{year}?view=#{socket.assigns.view_mode}")}
  end

  @impl true
  def handle_event("month_selected", %{"month" => month}, socket) do
    month = String.to_integer(month)
    {:noreply, push_patch(socket, to: ~p"/calendar/#{socket.assigns.selected_year}/#{month}?view=#{socket.assigns.view_mode}")}
  end

  @impl true
  def handle_event("view_mode_changed", %{"view_mode" => view_mode}, socket) do
    case view_mode do
      "month" ->
        {:noreply, push_patch(socket, to: ~p"/calendar/#{socket.assigns.selected_year}/#{socket.assigns.selected_month}?view=month")}
      "2month" ->
        {:noreply, push_patch(socket, to: ~p"/calendar/#{socket.assigns.selected_year}/#{socket.assigns.selected_month}?view=2month")}
      "year" ->
        {:noreply, push_patch(socket, to: ~p"/calendar/#{socket.assigns.selected_year}?view=year")}
    end
  end

  defp load_events(socket) do
    year = socket.assigns.selected_year
    month = socket.assigns.selected_month
    view_mode = socket.assigns.view_mode

    # Get current user from current_scope
    current_user = socket.assigns.current_scope.user

    case view_mode do
      "month" ->
        load_month_view(socket, year, month, current_user)
      "2month" ->
        load_2month_view(socket, year, month, current_user)
      "year" ->
        load_year_view(socket, year, current_user)
    end
  end

  defp load_month_view(socket, year, month, current_user) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.new!(year, month, Date.days_in_month(start_date))

    events = Events.get_events_by_date_range_ignore_year(start_date, end_date, current_user.id)
    events_by_date = group_events_by_date(events)

    calendar_months = [
      %{
        month: month,
        year: year,
        days: generate_calendar_days(year, month, events_by_date)
      }
    ]

    socket
    |> assign(:events_by_date, events_by_date)
    |> assign(:calendar_months, calendar_months)
    |> assign(:view_title, "#{month_name(month)} #{year}")
  end

  defp load_2month_view(socket, year, month, current_user) do
    # Calculate the two months to show (current and next)
    {first_month, first_year, second_month, second_year} =
      if month == 12 do
        {month, year, 1, year + 1}
      else
        {month, year, month + 1, year}
      end

        # Get events for both months
    first_start = Date.new!(first_year, first_month, 1)
    _first_end = Date.new!(first_year, first_month, Date.days_in_month(first_start))

    second_start = Date.new!(second_year, second_month, 1)
    second_end = Date.new!(second_year, second_month, Date.days_in_month(second_start))

    events = Events.get_events_by_date_range_ignore_year(first_start, second_end, current_user.id)
    events_by_date = group_events_by_date(events)

    calendar_months = [
      %{
        month: first_month,
        year: first_year,
        days: generate_calendar_days(first_year, first_month, events_by_date)
      },
      %{
        month: second_month,
        year: second_year,
        days: generate_calendar_days(second_year, second_month, events_by_date)
      }
    ]

    socket
    |> assign(:events_by_date, events_by_date)
    |> assign(:calendar_months, calendar_months)
    |> assign(:view_title, "#{month_name(first_month)} #{first_year} - #{month_name(second_month)} #{second_year}")
  end

  defp load_year_view(socket, year, current_user) do
    start_date = Date.new!(year, 1, 1)
    end_date = Date.new!(year, 12, 31)

    events = Events.get_events_by_date_range_ignore_year(start_date, end_date, current_user.id)
    events_by_date = group_events_by_date(events)

    calendar_months = for month <- 1..12 do
      %{
        month: month,
        year: year,
        days: generate_calendar_days(year, month, events_by_date)
      }
    end

    socket
    |> assign(:events_by_date, events_by_date)
    |> assign(:calendar_months, calendar_months)
    |> assign(:view_title, "#{year}")
  end

  defp group_events_by_date(events) do
    events
    |> Enum.group_by(fn event -> event.date end)
  end

  defp get_events_for_date_ignore_year(events_by_date, date) do
    # Get events that match the month and day, regardless of year
    events_by_date
    |> Enum.filter(fn {event_date, _events} ->
      event_date.month == date.month and event_date.day == date.day
    end)
    |> Enum.flat_map(fn {_date, events} -> events end)
  end

  defp has_birthday?(events) do
    Enum.any?(events, fn event -> event.category == "birthday" end)
  end

  defp has_anniversary?(events) do
    Enum.any?(events, fn event -> event.category == "anniversary" end)
  end

  defp has_graduation?(events) do
    Enum.any?(events, fn event -> event.category == "graduation" end)
  end

  defp has_retirement?(events) do
    Enum.any?(events, fn event -> event.category == "retirement" end)
  end

  defp has_wedding?(events) do
    Enum.any?(events, fn event -> event.category == "wedding" end)
  end

  defp has_holiday?(events) do
    Enum.any?(events, fn event -> event.category == "holiday" end)
  end

  defp has_work?(events) do
    Enum.any?(events, fn event -> event.category == "work" end)
  end

  defp has_personal?(events) do
    Enum.any?(events, fn event -> event.category == "personal" end)
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
        has_anniversary: has_anniversary?(events),
        has_graduation: has_graduation?(events),
        has_retirement: has_retirement?(events),
        has_wedding: has_wedding?(events),
        has_holiday: has_holiday?(events),
        has_work: has_work?(events),
        has_personal: has_personal?(events)
      }
    end

    empty_cells ++ month_days
  end
end
