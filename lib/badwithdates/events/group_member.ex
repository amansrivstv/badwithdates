defmodule Badwithdates.Events.GroupMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group_members" do
    field :role, :string, default: "member"
    belongs_to :group, Badwithdates.Events.UserGroup
    belongs_to :user, Badwithdates.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(group_member, attrs) do
    group_member
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, ["member", "admin"])
    |> unique_constraint([:group_id, :user_id], name: :group_members_group_id_user_id_index)
  end

  def is_admin?(%__MODULE__{role: "admin"}), do: true
  def is_admin?(_), do: false
end
