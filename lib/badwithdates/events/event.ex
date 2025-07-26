defmodule Badwithdates.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string
    field :date, :date
    field :category, Ecto.Enum, values: [:anniversary, :birthday]
    field :description, :string
    belongs_to :user, Badwithdates.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs, user_scope) do
    event
    |> cast(attrs, [:title, :date, :category, :description])
    |> validate_required([:title, :date, :category, :description])
    |> put_change(:user_id, user_scope.user.id)
  end
end
