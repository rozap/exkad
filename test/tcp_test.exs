defmodule TcpTest do
  use ExUnit.Case
  alias Exkad.{Knode, Hash, Connection}
  import Exkad.Tcp.Wire


  defp accept_connections(listener, agent) do
    {:ok, sock} = :gen_tcp.accept(listener)
    {:ok, bin} = do_receive(sock)

    Agent.update(agent, fn _ -> bin end)

    response = serialize!(:mock_response)
    
    :ok = :gen_tcp.send(sock, response)
    :ok = :gen_tcp.shutdown(sock, :read_write)
    # :ok = :gen_tcp.close(sock)
    accept_connections(listener, agent)
  end

  defp serve(port, agent) do
    {:ok, listener} = :gen_tcp.listen(port, [:binary, {:packet, 0}, {:active, false}])
    accept_connections(listener, agent)
    # :ok = :gen_tcp.close(listener)
  end

  test "can make requests" do
    peer = %Knode.TCPPeer{
      ip: "localhost",
      port: Enum.random(2000..4000)
    }

    {:ok, agent} = Agent.start_link(fn -> nil end)
    spawn_link(fn -> serve(peer.port, agent) end)

    assert Connection.get(peer, "foo") == :mock_response
    request = Agent.get(agent, fn s -> s end)
    assert request == {:get, "foo"}

    assert Connection.put(peer, "foo", "bar") == :mock_response
    request = Agent.get(agent, fn s -> s end)
    assert request == {:put, "foo", "bar"}

    from = %Knode.TCPPeer{
      ip: "localhost",
      port: 5000
    }
    assert Connection.ping(peer, from) == :mock_response
    request = Agent.get(agent, fn s -> s end)
    assert request == {:ping, from}

    assert Connection.k_closest(peer, "boo", [], from) == :mock_response
    request = Agent.get(agent, fn s -> s end)
    assert request == {:k_closest, "boo", from}
  end

end
