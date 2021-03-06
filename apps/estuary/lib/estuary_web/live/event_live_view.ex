defmodule EstuaryWeb.EventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.EventLiveView.Table
  alias Estuary.Services.EventRetrievalService

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Events</h1>
      <%= live_component(@socket, Table, id: :events_table, events: @events) %>
    </div>
    """
  end

  def mount(_session, socket) do
    {:ok, events} = EventRetrievalService.get_all()
    {:ok, assign(socket, events: events)}
  end
end
