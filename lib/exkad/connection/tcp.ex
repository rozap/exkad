defimpl Exkad.Connection, for: Exkad.Knode.TCPPeer do
  import Exkad.Tcp.Wire
  alias Exkad.Knode.{Peer, TCPPeer}
  alias Exkad.Connection, as: C

  def start_link(external, internal) do
    _pid = spawn_link(fn ->
      serve(external.port, internal)
    end)

    :ok
  end

  defp serve(port, %Peer{} = peer) do
    {:ok, listener} = :gen_tcp.listen(port, [:binary, {:packet, 0}, {:active, false}])
    accept_connections(listener, peer)
  end

  defp accept_connections(listener, %Peer{} = peer) do
    {:ok, sock} = :gen_tcp.accept(listener)

    response = with {:ok, request} <- do_receive(sock) do
      dispatch(request, peer)
    end

    :ok = :gen_tcp.send(sock, serialize!(response))
    :ok = :gen_tcp.shutdown(sock, :read_write)
    :ok = :gen_tcp.close(sock)
    accept_connections(listener, peer)
  end

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

  defp dispatch({:ping, from}, peer),           do: C.ping(peer, from)
  defp dispatch({:put, key, value}, peer),      do: C.put(peer, key, value)
  defp dispatch({:get, key}, peer),             do: C.get(peer, key)
  defp dispatch({:k_closest, key, from}, peer), do: C.k_closest(peer, key, from)

  def ping(peer, from),               do: request(peer, {:ping, from})
  def put(peer, key, value),          do: request(peer, {:put, key, value})
  def get(peer, key),                 do: request(peer, {:get, key})
  def k_closest(peer, key, from \\ :nobody), do: request(peer, {:k_closest, key, from})
end