defmodule Badwithdates.Events.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Plug.Conn, only: [get_req_header: 2]

  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :integer
    field :details, :map
    field :ip_address, :string
    field :user_agent, :string
    belongs_to :user, Badwithdates.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:action, :resource_type, :resource_id, :details, :ip_address, :user_agent])
    |> validate_required([:action, :resource_type])
    |> validate_inclusion(:action, valid_actions())
    |> validate_length(:ip_address, max: 45)
    |> validate_length(:user_agent, max: 500)
  end

  defp valid_actions do
    [
      "create", "update", "delete", "view", "export", "import",
      "share", "login", "logout", "password_change", "settings_update"
    ]
  end

  def log_action(user_id, action, resource_type, resource_id \\ nil, details \\ %{}, conn \\ nil) do
    attrs = %{
      user_id: user_id,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      details: details,
      ip_address: get_ip_address(conn),
      user_agent: get_user_agent(conn)
    }

    %__MODULE__{}
    |> changeset(attrs)
    |> Badwithdates.Repo.insert()
  end

  defp get_ip_address(nil), do: nil
  defp get_ip_address(conn) do
    conn.remote_ip
    |> :inet.ntoa()
    |> to_string()
  end

  defp get_user_agent(nil), do: nil
  defp get_user_agent(conn) do
    get_req_header(conn, "user-agent")
    |> List.first()
  end
end
