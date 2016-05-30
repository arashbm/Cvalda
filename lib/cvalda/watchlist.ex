
defmodule Cvalda.Watchlist do
  use GenServer
  require Logger

  ## Public API

  def start_link(opts) do
    opts = [redis_uri: "redis://localhost:6379/1", cooldown: 5000]
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def reschedule(key, time) do
    GenServer.call(__MODULE__, {:reschedule, key, time})
  end

  ## GenServer Callback

  def init(opts) do
    #TODO connect to redis
    {:ok, redis} = Redix.start_link(opts[:redis_uri])
    send self(), :check_scheduler
    {:ok, [redis: redis, cooldown: opts[:cooldown]]}
  end

  def handle_info(:check_scheduler, state) do
    #FIXME there is a chance of adding a job multiple times to queue
    now = :os.system_time(:seconds)
    redis_command = ["ZRANGEBYSCORE", "todo", "-inf", now]
    {:ok, list} = Redix.command(state[:redis], redis_command)
    case list do
      [] ->
        :ok
      _ ->
        Logger.info "moving #{inspect list} to tasks queue"
        multi = [
          ["MULTI"],
          List.flatten(["ZADD", "todo", "XX",
            (for i <- list, do: [to_string(now + 60), i])]),
          List.flatten(["RPUSH", "tasks", list]),
          ["EXEC"]
        ]
        {:ok, results} = Redix.pipeline(state[:redis], multi)
        #FIXME actually check the results
        Logger.info("Results: #{inspect results}")
    end
    Process.send_after self(), :check_scheduler, state[:cooldown]
    {:noreply, state}
  end

  def handle_call({:reschedule, key, time}, _from, state) do
    {:ok, _} = Redix.pipeline(state[:redis], ["ZADD", "todo", "XX", time, key])
    {:reply, :ok}
  end
end
