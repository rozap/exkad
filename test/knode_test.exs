defmodule KnodeTest do
  use ExUnit.Case
  alias Exkad.{Knode, Hash, Connection}
  import TestHelper

  @count 8
  @k 16

  defp make_pool  do
    seed = make("seed")

    peers = "abcdefghijklmnopqrstuvwxyz"
    |> String.split("", trim: true)
    |> Enum.map(&make/1)

    Enum.each(peers, fn a ->
      Knode.connect(a, seed)
    end)

    peers
  end

  test "can ping" do
    a = make("a")
    b = make("b")

    assert :ok == Knode.connect(a, b)

    [b_peer] = List.flatten((Knode.dump(a)).buckets)
    [a_peer] = List.flatten((Knode.dump(b)).buckets)

    assert b_peer == b
    assert a_peer == a
  end

  test "can store" do
    a = make("a")
    assert :ok == Connection.put(a, "foo", "bar")
    assert Knode.dump(a).data == %{"foo" => "bar"}
  end

  test "can iteratively get k closest" do
    nodes = make_pool
    z = List.last(nodes)
    [closest | _] = Knode.lookup_node(z, "a")
    assert closest.name == "a"
  end

  test "can put things on the right node" do
    _ = make("a")
    _ = make("b")
    c = make("c")

    Knode.store(c, "a", "an a")
    assert {:ok, "an a"} == Connection.get(c, "a")

    a = make("a")
    b = make("b")
    c = make("c")

    Knode.connect(a, b)
    Knode.connect(b, c)
    :timer.sleep(50)
    Knode.store(c, "a", "an a")
    assert {:error, :not_found} == Connection.get(c, "a")
    assert {:ok, ["an a"]} == Knode.lookup(c, "a")

    assert peers_of(a) == ["b", "c"]
    assert peers_of(b) == ["a", "c"]
    assert peers_of(c) == ["a", "b"]
  end

  test "can iteratively store" do
    nodes = make_pool
    z = List.last(nodes)
    assert {:error, _} = Knode.lookup(z, "a")
    Knode.store(z, "a", "foo")
    assert {:ok, ["foo"]} = Knode.lookup(z, "a")
  end

end
