defmodule Cvalda.ResourceWorker do
  use GenServer
  require Logger

  def start_link(opts) do
    opts = [
      redis_uri: "redis://localhost:6379/1",
      timeout: 10,
      task_queue: "tasks"
    ]
    GenServer.start_link(__MODULE__, opts, [])
  end

  def init(opts) do
    {:ok, redis} = Redix.start_link(opts[:redis_uri])
    send self(), :get_job
    {:ok, [
        redis: redis,
        timeout: opts[:timeout],
        task_queue: opts[:task_queue]
      ]}
  end

  def handle_info(:get_job, state) do
    queue = state[:task_queue]
    # Block on blpop for 'timeout' miliseconds to get a job
    blpop = ["BLPOP", queue, state[:timeout]]
    {:ok, res} = Redix.command(state[:redis],
                                blpop,
                                timeout: (state[:timeout]+5)*1000)
    case res do
      nil ->
        :ok
      [^queue, key] ->
        Logger.info "Performing request for URI #{inspect key}"
    end

    send self(), :get_job
    {:noreply, state}
  end
end
