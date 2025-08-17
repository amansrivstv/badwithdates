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

    # Check for reminders for different intervals
    check_reminders_for_date(Date.add(today, 30), :thirty_day)
    check_reminders_for_date(Date.add(today, 14), :fourteen_day)
    check_reminders_for_date(Date.add(today, 7), :seven_day)
    check_reminders_for_date(Date.add(today, 3), :three_day)
    check_reminders_for_date(Date.add(today, 1), :one_day)
    check_reminders_for_date(today, :same_day)

    :ok
  end

  defp check_reminders_for_date(target_date, reminder_type) do
    # Get all events that match the month and day of target_date
    events = Events.get_events_for_month_day(target_date.month, target_date.day)

    Enum.each(events, fn event ->
      # Check if we should send a reminder for this event
      if should_send_reminder?(event, target_date, reminder_type) do
        # Get reminder preferences for this event
        case Events.get_reminder_preference(event.id) do
          nil ->
            # Use default preferences
            send_default_reminder(event, target_date, reminder_type)

          preference ->
            if preference.enabled and reminder_type in preference.reminder_days do
              send_custom_reminder(event, target_date, reminder_type, preference)
            end
        end
      end
    end)
  end

  defp should_send_reminder?(event, target_date, reminder_type) do
    # Check if we've already sent this type of reminder for this year
    !Events.reminder_already_sent?(event.id, target_date.year, reminder_type)
  end

  defp send_default_reminder(event, target_date, reminder_type) do
    # Only send default reminders for 1 day and 7 day intervals
    if reminder_type in [:one_day, :seven_day] do
      %{
        event_id: event.id,
        event_title: event.title,
        event_description: event.description,
        category: event.category,
        email: event.user.email,
        reminder_type: reminder_type,
        event_date: target_date,
        custom_message: nil
      }
      |> ReminderSender.new()
      |> Oban.insert()
    end
  end

  defp send_custom_reminder(event, target_date, reminder_type, preference) do
    %{
      event_id: event.id,
      event_title: event.title,
      event_description: event.description,
      category: event.category,
      email: event.user.email,
      reminder_type: reminder_type,
      event_date: target_date,
      custom_message: preference.custom_message,
      notification_type: preference.notification_type
    }
    |> ReminderSender.new()
    |> Oban.insert()
  end
end
