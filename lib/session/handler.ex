defmodule Gateway.Session do
  use GenServer

  defstruct session_id: nil,
            linked_socket: nil

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: :"#{state.session_id}")
  end

  def init(state) do
    {:ok,
     %__MODULE__{
       session_id: state.session_id,
       linked_socket: nil
     }, {:continue, :setup_session}}
  end

  def handle_continue(:setup_session, state) do
    {:noreply, state}
  end

  def handle_info({:send_to_socket, message}, state) do
    send(state.linked_socket, {:remote_send, message})

    {:noreply, state}
  end

  def handle_info({:send_to_socket, message, socket}, state) when is_pid(socket) do
    send(socket, {:remote_send, message})

    {:noreply, state}
  end

  def handle_info({:send_init, socket}, state) when is_pid(socket) do
    send(socket, {:send_op, 0, %{heartbeat_interval: 25000}})

    {:noreply, state}
  end

  def handle_info({:send_leaderboard, data}, state) do
    send(state.linked_socket, {:send_op, 1, data})

    {:noreply, state}
  end

  def handle_info({:send_post, data}, state) do
    send(state.linked_socket, {:send_op, 2, data})

    {:noreply, state}
  end

  def handle_cast({:link_socket, socket_pid}, state) do
    IO.puts("Linking socket to session #{state.session_id}")

    send(self(), {:send_init, socket_pid})

    {:noreply,
     %{
       state
       | linked_socket: socket_pid
     }}
  end
end
