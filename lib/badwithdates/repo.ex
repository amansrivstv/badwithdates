defmodule Badwithdates.Repo do
  use Ecto.Repo,
    otp_app: :badwithdates,
    adapter: Ecto.Adapters.Postgres
end
