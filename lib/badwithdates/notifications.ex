defmodule Badwithdates.Notifications do
  import Swoosh.Email
  alias Badwithdates.Mailer

  def send_reminder_email(recipient, event, message) do
    email =
      new()
      |> to(recipient)
      |> from({"Badwithdates", "contact@example.com"})
      |> subject(event)
      |> text_body(message)

    Mailer.deliver(email)
  end
end
