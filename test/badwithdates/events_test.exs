defmodule Badwithdates.EventsTest do
  use Badwithdates.DataCase

  alias Badwithdates.Events

  describe "events" do
    alias Badwithdates.Events.Event

    import Badwithdates.AccountsFixtures, only: [user_scope_fixture: 0]
    import Badwithdates.EventsFixtures

    @invalid_attrs %{date: nil, description: nil, title: nil, category: nil}

    test "list_events/1 returns all scoped events" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)
      other_event = event_fixture(other_scope)
      assert Events.list_events(scope) == [event]
      assert Events.list_events(other_scope) == [other_event]
    end

    test "get_event!/2 returns the event with given id" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      other_scope = user_scope_fixture()
      assert Events.get_event!(scope, event.id) == event
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(other_scope, event.id) end
    end

    test "create_event/2 with valid data creates a event" do
      valid_attrs = %{date: ~D[2025-07-23], description: "some description", title: "some title", category: :anniversary}
      scope = user_scope_fixture()

      assert {:ok, %Event{} = event} = Events.create_event(scope, valid_attrs)
      assert event.date == ~D[2025-07-23]
      assert event.description == "some description"
      assert event.title == "some title"
      assert event.category == :anniversary
      assert event.user_id == scope.user.id
    end

    test "create_event/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.create_event(scope, @invalid_attrs)
    end

    test "update_event/3 with valid data updates the event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      update_attrs = %{date: ~D[2025-07-24], description: "some updated description", title: "some updated title", category: :birthday}

      assert {:ok, %Event{} = event} = Events.update_event(scope, event, update_attrs)
      assert event.date == ~D[2025-07-24]
      assert event.description == "some updated description"
      assert event.title == "some updated title"
      assert event.category == :birthday
    end

    test "update_event/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)

      assert_raise MatchError, fn ->
        Events.update_event(other_scope, event, %{})
      end
    end

    test "update_event/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Events.update_event(scope, event, @invalid_attrs)
      assert event == Events.get_event!(scope, event.id)
    end

    test "delete_event/2 deletes the event" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      assert {:ok, %Event{}} = Events.delete_event(scope, event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(scope, event.id) end
    end

    test "delete_event/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      event = event_fixture(scope)
      assert_raise MatchError, fn -> Events.delete_event(other_scope, event) end
    end

    test "change_event/2 returns a event changeset" do
      scope = user_scope_fixture()
      event = event_fixture(scope)
      assert %Ecto.Changeset{} = Events.change_event(scope, event)
    end
  end
end
