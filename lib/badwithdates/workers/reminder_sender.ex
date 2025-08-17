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
          "event_date" => event_date,
          "custom_message" => custom_message,
          "notification_type" => notification_type
        }
      }) do

    event_date = Date.from_iso8601!(event_date)

    # Send the actual reminder
    send_reminder(event_title, email, event_date, String.to_atom(reminder_type), custom_message, notification_type)
    Events.record_reminder_sent(event_id, event_date.year, String.to_atom(reminder_type))

    :ok
  end

  defp send_reminder(event_title, email, event_date, reminder_type, custom_message, notification_type) do
    message = build_reminder_message(event_title, email, event_date, reminder_type, custom_message)

    case notification_type do
      "email" -> Notifications.send_reminder_email(email, event_title, message)
      "sms" -> Notifications.send_reminder_sms(email, event_title, message)
      "push" -> Notifications.send_reminder_push(email, event_title, message)
      "all" ->
        Notifications.send_reminder_email(email, event_title, message)
        Notifications.send_reminder_sms(email, event_title, message)
        Notifications.send_reminder_push(email, event_title, message)
      _ -> Notifications.send_reminder_email(email, event_title, message)
    end
  end

  defp build_reminder_message(event_title, email, event_date, reminder_type, custom_message) do
    if custom_message && custom_message != "" do
      custom_message
    else
      case reminder_type do
        :same_day ->
          "Hi #{email}! Today is #{event_title} on #{format_date(event_date)}. Don't forget to celebrate!"

        :one_day ->
          "Hi #{email}! Don't forget: #{event_title} is tomorrow on #{format_date(event_date)}."

        :three_day ->
          "Hi #{email}! #{event_title} is coming up in 3 days on #{format_date(event_date)}."

        :seven_day ->
          "Hi #{email}! Don't forget: #{event_title} is coming up on #{format_date(event_date)} (in 7 days)."

        :fourteen_day ->
          "Hi #{email}! #{event_title} is coming up in 2 weeks on #{format_date(event_date)}."

        :thirty_day ->
          "Hi #{email}! #{event_title} is coming up in a month on #{format_date(event_date)}."

        _ ->
          "Hi #{email}! Don't forget: #{event_title} on #{format_date(event_date)}."
      end
    end
  end

  defp format_date(date) do
    Calendar.strftime(date, "%B %d")
  end
end
