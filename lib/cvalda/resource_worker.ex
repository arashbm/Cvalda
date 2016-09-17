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
      [^queue, uri] ->
        proccess_resource(state[:redis], uri)
    end

    send self(), :get_job
    {:noreply, state}
  end

  defp proccess_resource(redis, uri) do
    case Cvalda.Resource.get_resource(redis, uri) do
      :not_found ->
        Logger.warn "URI #{inspect uri} was requested but not found in resources"
      {^uri, headers, etag, last_fetched} ->
        fetch_resource(redis, uri, headers, etag, last_fetched)
    end
  end

  defp fetch_resource(redis, uri, headers, etag, _last_fetched) do
    time = :os.system_time(:seconds)
    case Cvalda.Resource.fetch(uri, headers, etag) do
      :not_modified -> :ok
      {:ok, new_etag, resp_headers, body} ->
        Cvalda.Resource.set_resource(redis, uri, headers, new_etag, time)
        Cvalda.UpdateQueue.dispatch_update(uri,
         :erlang.term_to_binary({new_etag, resp_headers, body}))
        :ok
      {:error, reason} ->
        #TODO: hardcode?!
        Logger.warn "Fetching URI #{inspect uri} failed, rescheduling."
        Cvalda.Watchlist.reschedule(uri, :os.system_time(:seconds)+10)
        {:error, reason}
    end
  end
end
