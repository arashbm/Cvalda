defmodule Cvalda do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Cvalda.Watchlist, [[]], []),
      worker(Cvalda.UpdateQueue, [[]], []),
      supervisor(Cvalda.ResourceSupervisor, [[]], [])
    ]

    opts = [strategy: :one_for_one, name: Cvalda.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    :ok = Cvalda.ResourceSupervisor.start_workers(5)

    {:ok, pid}
  end
end
