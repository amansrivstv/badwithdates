defmodule Badwithdates.Notifications do
  import Swoosh.Email
  alias Badwithdates.Mailer

  def send_reminder_email(recipient, event, message) do
    email =
      new()
      |> to(recipient)
      |> from({"Bad With Dates", "amansrivstv@gmail.com"})
      |> subject(event)
      |> text_body(message)

    Mailer.deliver(email)
  end

  # Placeholder functions for SMS and Push notifications
  def send_reminder_sms(recipient, event, message) do
    # TODO: Implement SMS notification
    # For now, just log the SMS
    IO.puts("SMS to #{recipient}: #{event} - #{message}")
    {:ok, "SMS sent"}
  end

  def send_reminder_push(recipient, event, message) do
    # TODO: Implement Push notification
    # For now, just log the push notification
    IO.puts("Push to #{recipient}: #{event} - #{message}")
    {:ok, "Push notification sent"}
  end
end
