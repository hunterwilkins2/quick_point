defmodule QuickPointWeb.TicketLive.FormComponent do
  use QuickPointWeb, :live_component

  alias QuickPoint.Tickets
  alias QuickPoint.Game.GameState

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage ticket records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="ticket-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="text" label="Description" />

        <:actions>
          <.button phx-disable-with="Saving...">Save Ticket</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{ticket: ticket} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Tickets.change_ticket(ticket))
     end)}
  end

  @impl true
  def handle_event("validate", %{"ticket" => ticket_params}, socket) do
    changeset = Tickets.change_ticket(socket.assigns.ticket, ticket_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"ticket" => ticket_params}, socket) do
    save_ticket(socket, socket.assigns.action, ticket_params)
  end

  defp save_ticket(socket, :edit_ticket, ticket_params) do
    case Tickets.update_ticket(
           socket.assigns.current_user,
           socket.assigns.room,
           socket.assigns.ticket,
           ticket_params
         ) do
      {:ok, ticket} ->
        GameState.edit_ticket(socket.assigns.room.id, ticket)

        {:noreply,
         socket
         |> put_flash(:info, "Ticket updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, :unauthorized_action} ->
        {:noreply,
         socket
         |> put_flash(:error, "Only moderators may preform that action")
         |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp save_ticket(socket, :new_ticket, ticket_params) do
    case Tickets.create_ticket(socket.assigns.current_user, socket.assigns.room, ticket_params) do
      {:ok, ticket} ->
        GameState.add_ticket(socket.assigns.room.id, ticket)

        {:noreply,
         socket
         |> put_flash(:info, "Ticket created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, :unauthorized_action} ->
        {:noreply,
         socket
         |> put_flash(:error, "Only moderators may preform that action")
         |> push_patch(to: socket.assigns.patch)}
    end
  end
end
