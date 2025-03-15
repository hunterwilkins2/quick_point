defmodule QuickPointWeb.CustomComponents do
  use Phoenix.Component
  use QuickPointWeb, :verified_routes

  import QuickPointWeb.CoreComponents

  attr :room, QuickPoint.Rooms.Room, required: true
  attr :ticket_filter, :string, required: true
  attr :active_tickets, :integer, required: true
  attr :completed_tickets, :integer, required: true
  attr :total_tickets, :integer, required: true

  def ticket_selector(assigns) do
    ~H"""
    <form class="flex space-x-8 mt-8" phx-change="filter">
      <div class="[&_[type=radio]]:hidden
        [&_[type=radio]:checked+label]:[text-shadow:_1px_0_0_currentColor]
        [&_[type=radio]:checked+label]:border-b-2
        [&_[type=radio]:checked+label]:border-blue-400
      ">
        <input
          type="radio"
          id="not_started"
          value="not_started"
          name="ticket_filter"
          checked={@ticket_filter == "not_started"}
        />
        <label
          for="not_started"
          class="py-2 flex items-center hover:[text-shadow:_1px_0_0_currentColor] [&_span]:[text-shadow:_none] cursor-pointer"
        >
          Active Tickets
          <span class="font-medium ml-2 flex justify-center items-center bg-gray-400 text-white w-5 h-5 rounded-full">
            {@active_tickets}
          </span>
        </label>
      </div>

      <div class="[&_[type=radio]]:hidden
        [&_[type=radio]:checked+label]:[text-shadow:_1px_0_0_currentColor]
        [&_[type=radio]:checked+label]:border-b-2
        [&_[type=radio]:checked+label]:border-blue-400
      ">
        <input
          type="radio"
          id="completed"
          value="completed"
          name="ticket_filter"
          checked={@ticket_filter == "completed"}
        />
        <label
          for="completed"
          class="py-2 flex items-center hover:[text-shadow:_1px_0_0_currentColor] [&_span]:[text-shadow:_none] cursor-pointer"
        >
          Completed Tickets
          <span class="font-medium ml-2 flex justify-center items-center bg-gray-400 text-white w-5 h-5 rounded-full">
            {@completed_tickets}
          </span>
        </label>
      </div>

      <div class="[&_[type=radio]]:hidden
        [&_[type=radio]:checked+label]:[text-shadow:_1px_0_0_currentColor]
        [&_[type=radio]:checked+label]:border-b-2
        [&_[type=radio]:checked+label]:border-blue-400
      ">
        <input
          type="radio"
          id="total"
          value="total"
          name="ticket_filter"
          checked={@ticket_filter == "total"}
        />
        <label
          for="total"
          class="py-2 flex items-center hover:[text-shadow:_1px_0_0_currentColor] [&_span]:[text-shadow:_none] cursor-pointer"
        >
          All Tickets
          <span class="font-medium ml-2 flex justify-center items-center bg-gray-400 text-white w-5 h-5 rounded-full">
            {@total_tickets}
          </span>
        </label>
      </div>
      <div class="flex-grow">
        <.link patch={~p"/rooms/#{@room}/tickets/new"} class="float-end">
          <.button>New Ticket</.button>
        </.link>
      </div>
    </form>
    """
  end
end
