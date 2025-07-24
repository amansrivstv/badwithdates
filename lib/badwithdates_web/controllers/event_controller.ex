defmodule BadwithdatesWeb.EventController do
  use BadwithdatesWeb, :controller

  alias Badwithdates.Events
  alias Badwithdates.Events.Event

  def index(conn, _params) do
    events = Events.list_events(conn.assigns.current_scope)
    render(conn, :index, events: events)
  end

  def new(conn, _params) do
    changeset =
      Events.change_event(conn.assigns.current_scope, %Event{
        user_id: conn.assigns.current_scope.user.id
      })

    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"event" => event_params}) do
    case Events.create_event(conn.assigns.current_scope, event_params) do
      {:ok, event} ->
        conn
        |> put_flash(:info, "Event created successfully.")
        |> redirect(to: ~p"/events/#{event}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    event = Events.get_event!(conn.assigns.current_scope, id)
    render(conn, :show, event: event)
  end

  def edit(conn, %{"id" => id}) do
    event = Events.get_event!(conn.assigns.current_scope, id)
    changeset = Events.change_event(conn.assigns.current_scope, event)
    render(conn, :edit, event: event, changeset: changeset)
  end

  def update(conn, %{"id" => id, "event" => event_params}) do
    event = Events.get_event!(conn.assigns.current_scope, id)

    case Events.update_event(conn.assigns.current_scope, event, event_params) do
      {:ok, event} ->
        conn
        |> put_flash(:info, "Event updated successfully.")
        |> redirect(to: ~p"/events/#{event}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, event: event, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    event = Events.get_event!(conn.assigns.current_scope, id)
    {:ok, _event} = Events.delete_event(conn.assigns.current_scope, event)

    conn
    |> put_flash(:info, "Event deleted successfully.")
    |> redirect(to: ~p"/events")
  end
end
