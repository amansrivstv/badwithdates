defmodule Badwithdates.Repo.Migrations.AddEnhancedEventFeatures do
  use Ecto.Migration

  def change do
    # Update events table with new features
    alter table(:events) do
      # Expand categories
      modify :category, :string, from: {:enum, [:anniversary, :birthday]}

      # Add new fields
      add :tags, {:array, :string}, default: []
      add :photo_url, :string
      add :is_public, :boolean, default: false
      add :priority, :integer, default: 1
      add :notes, :text
      add :location, :string
      add :recurring, :boolean, default: true
    end

    # Create reminder preferences table
    create table(:reminder_preferences) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :reminder_days, {:array, :integer}, default: [1, 7]
      add :enabled, :boolean, default: true
      add :notification_type, :string, default: "email"
      add :custom_message, :text

      timestamps(type: :utc_datetime)
    end

    # Create event shares table for social features
    create table(:event_shares) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :shared_by_user_id, references(:users, on_delete: :delete_all), null: false
      add :shared_with_email, :string
      add :shared_with_name, :string
      add :share_token, :string, null: false
      add :expires_at, :utc_datetime
      add :viewed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Create user groups table for family/friend management
    create table(:user_groups) do
      add :name, :string, null: false
      add :description, :text
      add :created_by_user_id, references(:users, on_delete: :delete_all), null: false
      add :is_public, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    # Create group members table
    create table(:group_members) do
      add :group_id, references(:user_groups, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, default: "member" # member, admin

      timestamps(type: :utc_datetime)
    end

    # Create audit logs table
    create table(:audit_logs) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :integer
      add :details, :map
      add :ip_address, :string
      add :user_agent, :string

      timestamps(type: :utc_datetime)
    end

    # Create indexes
    create index(:reminder_preferences, [:event_id])
    create index(:event_shares, [:event_id])
    create index(:event_shares, [:share_token])
    create index(:event_shares, [:shared_with_email])
    create index(:user_groups, [:created_by_user_id])
    create index(:group_members, [:group_id])
    create index(:group_members, [:user_id])
    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:events, [:tags], using: :gin)
    create index(:events, [:is_public])
    create index(:events, [:priority])
  end
end
