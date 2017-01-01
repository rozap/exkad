defmodule TcpTest do
  use ExUnit.Case
  alias Exkad.{Knode, Hash, Connection}

  test "can put and get" do
    a = Knode.new({nil, "a"}, tcp: [port: 2222])
    local_b = Knode.new({nil, "b"}, tcp: [port: 3333])
    b = %Knode.TCPPeer{
      location: "localhost:3333",
      id: local_b.id,
      name: local_b.name
    }

    Knode.connect(a, b) |> IO.inspect


    Knode.store(a, "b", "a b value")
    assert {:ok, "a b value"} == Connection.get(a, "b")
    assert {:ok, "a b value"} == Connection.get(local_b, "b")

  end


end
