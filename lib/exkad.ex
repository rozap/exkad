defmodule Exkad do
  use Application
  import Supervisor.Spec
  require Logger
  alias Exkad.Knode

  @replication Application.get_env(:exkad, :replication, 1)


  def start(_type, children) do
    Logger.info("Starting Exkad")
    children = case Application.get_env(:exkad, :seed) do
      {pubkey, opts} ->
        seed = Knode.seed(pubkey, opts)
        Enum.map(children, fn {keypair, child_opts} ->
          {keypair, Keyword.put(child_opts, :seed, seed)}
        end)
      _ -> children
    end

    Logger.info("Exkad is starting with #{length children}")

    child_specs = Enum.map(children, fn {{_, pub} = keypair, opts} ->
      worker(Knode, [keypair, opts], id: pub)
    end)

    opts = [
      strategy: :one_for_one,
      name: Exkad.Supervisor
    ]

    Supervisor.start_link(child_specs, opts)
  end

  defp choose do
    case :pg2.get_members(:exkad) do
      [] ->      {:error, :no_group_members}
      members -> {:ok, Enum.random(members)}
    end
  end

  def store(key, value) do
    with {:ok, pid} <- choose(),
      {:ok, peer} <- Knode.peer_of(pid) do
      Knode.store(peer, key, value, @replication)
    end
  end

  def lookup(key) do
    with {:ok, pid} <- choose(),
      {:ok, peer} <- Knode.peer_of(pid) do
      Knode.lookup(peer, key)
    end
  end
end
