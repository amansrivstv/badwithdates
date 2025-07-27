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
end
