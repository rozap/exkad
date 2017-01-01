defimpl Exkad.Connection, for: Exkad.Knode.TCPPeer do
  alias Exkad.Knode.Peer

  def ping(peer, from) do
  end

  def put(peer, key, value, refs \\ []) do

  end

  def get(peer, key, refs \\ []) do
    {:error, :not_found}
  end

  def k_closest(peer, key, refs \\ [], from \\ :nobody) do
    []
  end
end