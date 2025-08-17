defmodule Badwithdates.Events.EventShare do
  use Ecto.Schema
  import Ecto.Changeset

  schema "event_shares" do
    field :shared_with_email, :string
    field :shared_with_name, :string
    field :share_token, :string
    field :expires_at, :utc_datetime
    field :viewed_at, :utc_datetime
    belongs_to :event, Badwithdates.Events.Event
    belongs_to :shared_by_user, Badwithdates.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event_share, attrs) do
    event_share
    |> cast(attrs, [:shared_with_email, :shared_with_name, :share_token, :expires_at, :viewed_at])
    |> validate_required([:shared_with_email, :share_token])
    |> validate_format(:shared_with_email, ~r/@/)
    |> validate_length(:shared_with_name, max: 255)
    |> validate_length(:share_token, min: 32, max: 64)
    |> unique_constraint(:share_token)
  end

  def generate_share_token do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  def is_expired?(%__MODULE__{expires_at: expires_at}) do
    case expires_at do
      nil -> false
      datetime -> DateTime.compare(datetime, DateTime.utc_now()) == :lt
    end
  end

  def is_viewed?(%__MODULE__{viewed_at: viewed_at}) do
    not is_nil(viewed_at)
  end
end
