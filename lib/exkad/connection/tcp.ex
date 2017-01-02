defimpl Exkad.Connection, for: Exkad.Knode.TCPPeer do
  import Exkad.Tcp.Wire

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

  def ping(peer, from), do: request(peer, {:ping, from})

  def put(peer, key, value, _ \\ []), do: request(peer, {:put, key, value})

  def get(peer, key, _ \\ []), do: request(peer, {:get, key})

  def k_closest(peer, key, refs \\ [], from \\ :nobody) do
    request(peer, {:k_closest, key, from}) 
  end
end