defimpl Exkad.Connection, for: Exkad.Knode.Peer do
  alias Exkad.Knode.Peer

  def start_link(peer, peer) do
    :ok
  end

  def ping(%Peer{} = peer, from) do
    GenServer.call(peer.location, {:ping, from})
  end

  def put(%Peer{} = peer, key, value, refs \\ []) do
    refs = [make_ref | refs]
    GenServer.call(peer.location, {:put, key, value, refs})
  end

  def get(%Peer{} = peer, key, refs \\ []) do
    refs = [make_ref | refs]
    GenServer.call(peer.location, {:get, key, refs})
  end

  def k_closest(%Peer{} = peer, key, refs \\ [], from \\ :nobody) do
    refs = [make_ref | refs]
    GenServer.call(peer.location, {:k_closest, key, from, refs}, 1000)
  end
end