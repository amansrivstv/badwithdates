defmodule Badwithdates.Workers.ReminderSender do
  use Oban.Worker, queue: :reminders

  alias Badwithdates.{Events, Notifications}

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "event_id" => event_id,
          "event_title" => event_title,
          "event_description" => _event_description,
          "category" => _category,
          "email" => email,
          "reminder_type" => reminder_type,
          "event_date" => event_date
        }
      }) do

    event_date = Date.from_iso8601!(event_date)

    # Send the actual reminder
    send_reminder(event_title, email, event_date, String.to_atom(reminder_type))
    Events.record_reminder_sent(event_id, event_date.year, String.to_atom(reminder_type))

    :ok
  end

  defp send_reminder(event_title, email, event_date, :seven_day) do
    message =
      "Hi #{email}! Don't forget: #{event_title} is coming up on #{format_date(event_date)} (in 7 days)."

    Notifications.send_reminder_email(email, event_title, message)
  end

  defp send_reminder(event_title, email, event_date, :one_day) do
    message =
      "Hi #{email}! Don't forget: #{event_title} on #{format_date(event_date)}. Don't forget!"

    Notifications.send_reminder_email(email, event_title, message)
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d")
  end
end
