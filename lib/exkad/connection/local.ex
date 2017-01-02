defimpl Exkad.Connection, for: Exkad.Knode.Peer do
  alias Exkad.Knode.Peer

  def start_link(peer, peer) do
    :ok
  end

  def ping(%Peer{} = peer, from) do
    GenServer.call(peer.location, {:ping, from})
  end

  def put(%Peer{} = peer, key, value) do
    GenServer.call(peer.location, {:put, key, value})
  end

  def get(%Peer{} = peer, key) do
    GenServer.call(peer.location, {:get, key})
  end

  def k_closest(%Peer{} = peer, key, from \\ :nobody) do
    GenServer.call(peer.location, {:k_closest, key, from}, 1000)
  end
end