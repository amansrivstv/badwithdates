defmodule Badwithdates.Events.UserGroup do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "user_groups" do
    field :name, :string
    field :description, :string
    field :is_public, :boolean, default: false
    belongs_to :created_by_user, Badwithdates.Accounts.User

    # Associations
    has_many :group_members, Badwithdates.Events.GroupMember, foreign_key: :group_id
    has_many :members, through: [:group_members, :user]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_group, attrs) do
    user_group
    |> cast(attrs, [:name, :description, :is_public])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, max: 1000)
  end

  def with_members(query) do
    query
    |> preload([:group_members, :members])
  end
end
