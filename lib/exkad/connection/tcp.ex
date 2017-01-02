defimpl Exkad.Connection, for: Exkad.Knode.TCPPeer do
  import Exkad.Tcp.Wire
  alias Exkad.Knode.Peer

  defp request(peer, body) do
    ip = String.to_charlist(peer.ip)
    with {:ok, sock} <- :gen_tcp.connect(ip, peer.port, [:binary, {:packet, 0}, {:active, false}]) do
      :ok = :gen_tcp.send(sock, serialize!(body))
      with {:ok, response} <- do_receive(sock) do
        :gen_tcp.close(sock)
        response
      end
    end    
  end

  defp serve(port, %Peer{} = peer) do
    {:ok, listener} = :gen_tcp.listen(port, [:binary, {:packet, 0}, {:active, false}])
    accept_connections(listener, peer)
  end

  defp accept_connections(listener, agent) do
    {:ok, sock} = :gen_tcp.accept(listener)
    {:ok, term} = do_receive(sock)

    # dispatch(term)

    response = serialize!(:mock_response)
    
    :ok = :gen_tcp.send(sock, response)
    :ok = :gen_tcp.shutdown(sock, :read_write)
    :ok = :gen_tcp.close(sock)
    accept_connections(listener, agent)
  end

  def start_link(external, internal) do
    _pid = spawn_link(fn ->
      serve(external.port, internal)
    end)

    :ok
  end

  def ping(peer, from), do: request(peer, {:ping, from})

  def put(peer, key, value, _ \\ []), do: request(peer, {:put, key, value})

  def get(peer, key, _ \\ []), do: request(peer, {:get, key})

  def k_closest(peer, key, refs \\ [], from \\ :nobody) do
    request(peer, {:k_closest, key, from}) 
  end
end