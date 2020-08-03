defmodule ThullaEngine.TableSupervisor do
  use DynamicSupervisor
  alias ThullaEngine.Table

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_game(name) do
    spec = %{
      id: Table,
      start: {Table, :start_link, [name]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_game(name) do
    :ets.delete(:table_state, name)
    DynamicSupervisor.terminate_child(__MODULE__, pid_from_name(name))
  end

  def init(_init_arg), do: DynamicSupervisor.init(strategy: :_one_for_one)

  def pid_from_name(name) do
    name
    |> Table.via_tuple()
    |> GenServer.whereis()
  end
end
