defmodule ThullaEngine.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ThullaEngine.Worker.start_link(arg)
      {Registry, keys: :unique, name: Registry.Table},
      {DynamicSupervisor, strategy: :one_for_one, name: ThullaEngine.TableSupervisor}
    ]
    :ets.new(:table_state, [:public, :named_table])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
