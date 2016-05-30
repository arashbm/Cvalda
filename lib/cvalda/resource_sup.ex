defmodule Cvalda.ResourceSupervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(opts) do
    children = [
      worker(Cvalda.ResourceWorker, [[]])
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  def start_workers(0) do
    :ok
  end

  def start_workers(num) do
    {:ok, _} = Supervisor.start_child(__MODULE__, [])
    start_workers(num-1)
  end
end
