defmodule Gateway.Connectivity.Rabbit do
  use GenServer
  use AMQP

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: :rabbit)
  end

  def init(_state) do
    {:ok, conn} = AMQP.Connection.open("#{Application.fetch_env!(:gateway, :rabbit_uri)}")
    {:ok, chan} = AMQP.Channel.open(conn)

    AMQP.Queue.declare(chan, "dstn-gm-gateway-ingest", durable: true)
    {:ok, _tag} = Basic.consume(chan, "dstn-gm-gateway-ingest")

    {:ok, chan}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _tag}}, chan) do
    {:stop, :normal, chan}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, routing_key: routing_key}}, chan) do
    Task.start(fn ->
      consume(chan, tag, routing_key, payload)
    end)

    {:noreply, chan}
  end

  defp consume(channel, tag, queue_name, payload) do
    :ok = Basic.ack(channel, tag)

    payload
    |> :erlang.binary_to_term()
    |> action(queue_name)
  rescue
    exception ->
      :ok = Basic.ack(channel, tag)
      IO.inspect(exception)
      IO.puts("Error converting #{payload} to term")
  end

  defp action(data, queue_name) do
    case queue_name do
      "dstn-gm-gateway-ingest" ->
        case data["t"] do
          0 ->
            {_max_id, _max_pid} =
              GenRegistry.reduce(Gateway.Session, {nil, -1}, fn
                {_id, pid}, {_, _current} = _acc ->
                  send(pid, {:send_leaderboard, data["d"]})
              end)

          1 ->
            {_max_id, _max_pid} =
              GenRegistry.reduce(Gateway.Session, {nil, -1}, fn
                {_id, pid}, {_, _current} = _acc ->
                  send(pid, {:send_post, data["d"]})
              end)

          2 ->
            {_max_id, _max_pid} =
              GenRegistry.reduce(Gateway.Session, {nil, -1}, fn
                {_id, pid}, {_, _current} = _acc ->
                  send(pid, {:send_official_leaderboard, data["d"]})
              end)
        end

      _ ->
        nil
    end
  end
end
