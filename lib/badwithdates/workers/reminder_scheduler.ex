defmodule Badwithdates.Workers.ReminderScheduler do
  use Oban.Worker, queue: :reminders

  alias Badwithdates.Events
  alias Badwithdates.Workers.ReminderSender

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    today =
      DateTime.utc_now()
      |> DateTime.add(5 * 3600 + 30 * 60, :second)  # Add 5:30 hours for India
      |> DateTime.to_date()

    # Check for reminders 7 days ahead
    check_reminders_for_date(Date.add(today, 7), :seven_day)

    # Check for reminders 1 day ahead
    check_reminders_for_date(Date.add(today, 1), :one_day)

    :ok
  end

  defp check_reminders_for_date(target_date, reminder_type) do
    # Get all events that match the month and day of target_date
    events = Events.get_events_for_month_day(target_date.month, target_date.day)
    Enum.each(events, fn event ->
      # Check if we should send a reminder for this event
      if should_send_reminder?(event, target_date, reminder_type) do
        %{
          event_id: event.id,
          event_title: event.title,
          event_description: event.description,
          category: event.category,
          email: event.user.email,
          reminder_type: reminder_type,
          event_date: target_date
        }
        |> ReminderSender.new()
        |> Oban.insert()
      end
    end)
  end

  defp should_send_reminder?(event, target_date, reminder_type) do
    # Checking if we've already sent this type of reminder for this year
    !Events.reminder_already_sent?(event.id, target_date.year, reminder_type)
  end
end
