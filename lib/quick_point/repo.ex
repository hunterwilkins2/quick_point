defmodule QuickPoint.Repo do
  use Ecto.Repo,
    otp_app: :quick_point,
    adapter: Ecto.Adapters.Postgres
end
