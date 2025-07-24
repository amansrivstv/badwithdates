defmodule BadwithdatesWeb.PageController do
  use BadwithdatesWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def resume(conn, _params) do
    file_path = Path.join(:code.priv_dir(:badwithdates), "/static/documents/resume.pdf")

    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("content-disposition", "inline; filename=\"resume.pdf\"")
    |> send_file(200, file_path)
  end
end
