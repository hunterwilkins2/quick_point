defmodule QuickPointWeb.CustomComponents do
  use Phoenix.Component
  use QuickPointWeb, :verified_routes

  import QuickPointWeb.CoreComponents

  attr :cards, :list, required: true
  attr :vote, :string, default: ""

  def cards(assigns) do
    ~H"""
    <form phx-change="voted" class="flex gap-10 flex-wrap justify-evenly">
      <.card :for={card <- @cards} value={card} is_checked={card == @vote} />
    </form>
    """
  end

  attr :value, :string, required: true
  attr :is_checked, :boolean, default: false

  def card(assigns) do
    ~H"""
    <div class="[&_[type=radio]:checked+label]:bg-blue-500
                [&_[type=radio]:checked+label]:text-white
                [&_[type=radio]:checked+label]:border-blue-600
                [&_[type=radio]:checked+label>div:nth-child(2)]:border-white
    ">
      <input
        type="radio"
        id={"card-#{@value}"}
        value={@value}
        name="vote"
        checked={@is_checked}
        class="hidden"
      />
      <label
        for={"card-#{@value}"}
        class="grid grid-rows-3 grid-cols-3 items-center justify-items-center cursor-pointer
          w-24 h-32 bg-neutral-200 border-2 border-stone-300 rounded-md text-neutral-600
          shadow-md select-none hover:border-blue-500"
      >
        <div class="col-1 row-1">{@value}</div>
        <div class="col-start-2 row-start-2 text-xl w-12 h-16 text-center leading-[3.5rem] border-2 border-stone-300 rounded-md">
          {@value}
        </div>
        <div class="col-start-3 row-start-3 rotate-180">{@value}</div>
      </label>
    </div>
    """
  end

  attr :room, QuickPoint.Rooms.Room, required: true
  attr :ticket_filter, :string, required: true
  attr :active_tickets, :integer, required: true
  attr :completed_tickets, :integer, required: true
  attr :total_tickets, :integer, required: true
  attr :is_moderator, :boolean, default: false

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
      <div :if={@is_moderator} class="flex-grow">
        <.link patch={~p"/rooms/#{@room}/tickets/new"} class="float-end">
          <.button>New Ticket</.button>
        </.link>
      </div>
    </form>
    """
  end
end
