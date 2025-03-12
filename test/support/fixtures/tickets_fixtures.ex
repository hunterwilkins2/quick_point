defmodule QuickPoint.TicketsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuickPoint.Tickets` context.
  """

  @doc """
  Generate a ticket.
  """
  def ticket_fixture(attrs \\ %{}) do
    {:ok, ticket} =
      attrs
      |> Enum.into(%{
        description: "some description",
        effort: 42,
        name: "some name",
        status: :not_started
      })
      |> QuickPoint.Tickets.create_ticket()

    ticket
  end
end
