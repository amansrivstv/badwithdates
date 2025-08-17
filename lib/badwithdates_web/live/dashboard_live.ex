defmodule BadwithdatesWeb.DashboardLive do
  use BadwithdatesWeb, :live_view

  alias Badwithdates.Dashboard
  alias Badwithdates.Events

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to events for real-time updates
      Events.subscribe_events(socket.assigns.current_scope)

      # Set up periodic updates
      :timer.send_interval(30000, self(), :update_dashboard)
    end

    {:ok, assign_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:created, _event}, socket) do
    {:noreply, assign_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:updated, _event}, socket) do
    {:noreply, assign_dashboard_data(socket)}
  end

  @impl true
  def handle_info({:deleted, _event}, socket) do
    {:noreply, assign_dashboard_data(socket)}
  end

  @impl true
  def handle_info(:update_dashboard, socket) do
    {:noreply, assign_dashboard_data(socket)}
  end

  @impl true
  def handle_event("filter", %{"category" => category}, socket) do
    events = if category == "all" do
      Events.list_events(socket.assigns.current_scope)
    else
      Events.list_events(socket.assigns.current_scope, %{category: category})
    end

    {:noreply, assign(socket, events: events)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    events = if String.trim(query) == "" do
      Events.list_events(socket.assigns.current_scope)
    else
      Events.search_events(socket.assigns.current_scope, query)
    end

    {:noreply, assign(socket, events: events, search_query: query)}
  end

  defp assign_dashboard_data(socket) do
    user_id = socket.assigns.current_scope.user.id

    socket
    |> assign(:summary, Dashboard.get_dashboard_summary(user_id))
    |> assign(:upcoming_events, Dashboard.get_upcoming_events(user_id, 7))
    |> assign(:todays_events, Dashboard.get_todays_events(user_id))
    |> assign(:overdue_events, Dashboard.get_overdue_events(user_id))
    |> assign(:category_breakdown, Dashboard.get_category_breakdown(user_id))
    |> assign(:priority_breakdown, Dashboard.get_priority_breakdown(user_id))
    |> assign(:reminder_stats, Dashboard.get_reminder_stats(user_id, 7))
    |> assign(:events, Events.list_events(socket.assigns.current_scope))
    |> assign(:search_query, "")
    |> assign(:selected_category, "all")
  end

  defp format_days_until(event) do
    days = Badwithdates.Events.Event.days_until_event(event)
    case days do
      0 -> "Today"
      1 -> "Tomorrow"
      days when days < 0 -> "#{abs(days)} days ago"
      days -> "in #{days} days"
    end
  end

  defp get_category_color(category) do
    case category do
      "birthday" -> "bg-pink-100 text-pink-700"
      "anniversary" -> "bg-purple-100 text-purple-700"
      "graduation" -> "bg-blue-100 text-blue-700"
      "retirement" -> "bg-green-100 text-green-700"
      "wedding" -> "bg-red-100 text-red-700"
      "holiday" -> "bg-yellow-100 text-yellow-700"
      "work" -> "bg-gray-100 text-gray-700"
      "personal" -> "bg-indigo-100 text-indigo-700"
      _ -> "bg-gray-100 text-gray-700"
    end
  end

  # Uncomment this function when you want to display priority colors
  # defp get_priority_color(priority) do
  #   case priority do
  #     1 -> "bg-green-100 text-green-700"
  #     2 -> "bg-blue-100 text-blue-700"
  #     3 -> "bg-yellow-100 text-yellow-700"
  #     4 -> "bg-orange-100 text-orange-700"
  #     5 -> "bg-red-100 text-red-700"
  #     _ -> "bg-gray-100 text-gray-700"
  #   end
  # end
end
