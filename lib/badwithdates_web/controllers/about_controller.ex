defmodule BadwithdatesWeb.AboutController do
  use BadwithdatesWeb, :controller

  def about(conn, _params) do
    render(conn, :about, layout: false)
  end
end
