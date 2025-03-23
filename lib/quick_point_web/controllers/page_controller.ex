defmodule QuickPointWeb.PageController do
  use QuickPointWeb, :controller

  def home(%{assigns: %{current_user: nil}} = conn, _params) do
    IO.inspect(conn.assigns)
    redirect(conn, to: ~p"/users/log_in")
  end

  def home(%{assigns: %{current_user: _user}} = conn, _params) do
    redirect(conn, to: ~p"/rooms")
  end
end
