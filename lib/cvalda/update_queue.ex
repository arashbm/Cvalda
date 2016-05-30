defmodule Cvalda.UpdateQueue do
  use GenServer
  use AMQP
  require Logger

  ## Public API

  def start_link([]) do
    opts = [
      amqp_uri: "amqp://guest:guest@localhost",
      exchange_name: "updates_exchange"
    ]
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def dispatch_update(uri, bin) do
    GenServer.call(__MODULE__, {:dispatch_update, uri, bin})
  end

  ## GenServer callbacks

  def init(opts) do
    {:ok, chan} = connect_amqp(opts[:amqp_uri], opts[:exchange_name])
    {:ok, [channel: chan, exchange_name: opts[:exchange_name]]}
  end

  def handle_call({:dispatch_update, uri, bin}, _from, state) do
    uri_topic = uri_to_topic(uri)
    :ok = AMQP.Basic.publish state[:channel], state[:exchange_name], uri_topic, bin
    {:reply, :ok}
  end

  ## Private API

  @spec uri_to_topic(binary) :: binary
  defp uri_to_topic(uri) do
    uri |> String.replace(~r/^https?:\/\//, '')
        |> String.replace('.', '_')
        |> String.replace('/', '.')
  end

  defp connect_amqp(amqp_uri, exchange_name) do
    case Connection.open(amqp_uri) do
      {:ok, conn} ->
        # link to the AMQP connection
        Process.link(conn.pid)
        # Everything else remains the same
        {:ok, chan} = Channel.open(conn)
        Exchange.declare(chan, exchange_name, :topic)
        {:ok, chan}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
