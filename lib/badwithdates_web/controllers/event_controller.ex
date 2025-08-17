defmodule BadwithdatesWeb.EventController do
  use BadwithdatesWeb, :controller

  alias Badwithdates.Events
  alias Badwithdates.Events.Event

  def index(conn, params) do
    # Handle search and filter parameters
    filters = %{}
    filters = if params["search"] && String.trim(params["search"]) != "" do
      Map.put(filters, :search, String.trim(params["search"]))
    else
      filters
    end

    filters = if params["category"] && params["category"] != "all" do
      Map.put(filters, :category, params["category"])
    else
      filters
    end

    events = Events.list_events(conn.assigns.current_scope, filters)

    render(conn, :index,
      events: events,
      search_query: params["search"] || "",
      selected_category: params["category"] || "all"
    )
  end

  def new(conn, _params) do
    changeset =
      Events.change_event(conn.assigns.current_scope, %Event{
        user_id: conn.assigns.current_scope.user.id
      })

    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"event" => event_params}) do
    # Process tags from comma-separated string to list
    event_params = process_event_params(event_params)

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

    # Process tags from comma-separated string to list
    event_params = process_event_params(event_params)

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

  def export(conn, _params) do
    # Create scope for the current user
    try do
      binary_data =
        Events.export_events_to_excel(conn.assigns.current_scope)
      conn
      |> put_resp_header("content-disposition", "attachment; filename=export.xlsx")
      |> put_resp_content_type(
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      )
      |> send_resp(200, binary_data)
    rescue
      error ->
        conn
        |> put_flash(:error, "Failed to export events: #{inspect(error)}")
        |> redirect(to: ~p"/events")
    end
  end

  # Show import form
  def import_form(conn, _params) do
    render(conn, :import_form)
  end

  # Handle file upload and import
  def import(conn, %{"upload" => upload_params}) do
    case upload_params do
      %Plug.Upload{path: temp_path, filename: filename} ->
        # Validate file extension
        if Path.extname(filename) in [".xlsx", ".xls"] do
          # Create scope for the current user
          case Events.import_events_from_excel(conn.assigns.current_scope, temp_path) do
            {:ok, %{successes: successes, failures: failures}} ->
              message = "Import completed! #{successes} events imported successfully"
              message = if failures > 0, do: "#{message}, #{failures} failed", else: message

              conn
              |> put_flash(:info, message)
              |> redirect(to: ~p"/events")

            {:error, reason} ->
              conn
              |> put_flash(:error, "Import failed: #{reason}")
              |> render(:import_form)
          end
        else
          conn
          |> put_flash(:error, "Please upload an Excel file (.xlsx or .xls)")
          |> render(:import_form)
        end

      _ ->
        conn
        |> put_flash(:error, "Please select a file to upload")
        |> render(:import_form)
    end
  end

  def import(conn, _params) do
    conn
    |> put_flash(:error, "Please select a file to upload")
    |> render(:import_form)
  end

  # Helper function to process event parameters
  defp process_event_params(params) do
    case params do
      %{"tags" => tags} when is_binary(tags) ->
        tags_list = tags
                    |> String.split(",")
                    |> Enum.map(&String.trim/1)
                    |> Enum.filter(&(&1 != ""))
        Map.put(params, "tags", tags_list)
      _ ->
        params
    end
  end
end
