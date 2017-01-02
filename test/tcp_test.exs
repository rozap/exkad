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
    :ok = :gen_tcp.close(sock)
    accept_connections(listener, agent)
  end

  defp serve(port, agent) do
    {:ok, listener} = :gen_tcp.listen(port, [:binary, {:packet, 0}, {:active, false}])
    accept_connections(listener, agent)
  end

  defp random_port() do
    Enum.random(2000..4000)
  end

  test "can make requests" do
    peer = %Knode.TCPPeer{
      ip: "localhost",
      port: random_port()
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

    assert Connection.k_closest(peer, "boo", from) == :mock_response
    request = Agent.get(agent, fn s -> s end)
    assert request == {:k_closest, "boo", from}
  end

  test "can start a node which will talk over tcp" do
    peer = Knode.new({nil, "a"}, [tcp: [port: 5000, ip: "localhost" ]])
    assert %Knode.Peer{} = peer
    assert Knode.dump(peer).me == %Knode.TCPPeer{
      port: 5000,
      ip: "localhost",
      id: Hash.hash("a"),
      name: "a",
      k: 16
    }
  end

  test "can start two tcp knodes and put/get" do
    a_port = random_port()
    b_port = random_port()
    a = Knode.new({nil, "a"}, [tcp: [port: a_port, ip: "localhost"]])
    b = Knode.new({nil, "b"}, [tcp: [port: b_port, ip: "localhost"]])

    Knode.connect(a, %Knode.TCPPeer{
      port: b_port,
      ip: "localhost",
      id: Hash.hash("b"),
      name: "b",
      k: 16
    })

    assert [:ok] == Knode.store(a, "b", "b value")
    assert {:ok, ["b value"]} = Knode.lookup(b, "b")
    assert {:ok, ["b value"]} = Knode.lookup(a, "b")
  end

end
