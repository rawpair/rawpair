defmodule BeyondTabsSocial.Chat do
  use GenServer
  alias Phoenix.PubSub

  @topic_prefix "room:"
  @history_limit 100

  # Start the Chat process
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(state), do: {:ok, state}

  # Subscribe the current process to the room
  def subscribe_to_room(room) do
    PubSub.subscribe(BeyondTabsSocial.PubSub, @topic_prefix <> room)
    get_history(room)
  end

  # Public API to broadcast a new message
  def broadcast_message(room, user, content) do
    message = %{
      user: user,
      content: content,
      timestamp: DateTime.utc_now()
    }

    GenServer.cast(__MODULE__, {:store_and_broadcast, room, message})
  end

  # Return last messages for the room
  def get_history(room) do
    GenServer.call(__MODULE__, {:get_history, room})
  end

  @impl true
  def handle_cast({:store_and_broadcast, room, message}, state) do
    updated_room_msgs = [message | Map.get(state, room, [])] |> Enum.take(@history_limit)
    new_state = Map.put(state, room, updated_room_msgs)

    PubSub.broadcast(BeyondTabsSocial.PubSub, @topic_prefix <> room, {:new_message, message})
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_history, room}, _from, state) do
    {:reply, Map.get(state, room, []), state}
  end
end
