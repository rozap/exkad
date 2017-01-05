defmodule KnodeTest do
  use ExUnit.Case
  alias Exkad.{Knode, Connection}
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
    :timer.sleep(10)

    [b_peer] = List.flatten((Knode.dump(a)).buckets)
    [a_peer] = List.flatten((Knode.dump(b)).buckets)

    assert b_peer == b
    assert a_peer == a
  end

  test "can iteratively get k closest" do
    nodes = make_pool
    z = List.last(nodes)
    [closest | _] = Knode.lookup_node(z, "a")
    assert closest.name == "a"
  end

  test "can put things on the right node" do
    _ = make("aa")
    _ = make("bb")
    c = make("cc")

    Knode.store(c, "aa", "an a")
    assert {:ok, ["an a"]} == Connection.get(c, "aa")
  end

  test "can iteratively put things on the right node" do
    a = make("aaa")
    b = make("bbb")
    c = make("ccc")

    Knode.connect(a, b)
    Knode.connect(b, c)
    :timer.sleep(50)
    Knode.store(c, "aaa", "an a")
    assert {:ok, []} == Connection.get(c, "aaa")
    assert {:ok, ["an a"]} == Knode.lookup(c, "aaa")

    assert peers_of(a) == ["bbb", "ccc"]
    assert peers_of(b) == ["aaa", "ccc"]
    assert peers_of(c) == ["aaa", "bbb"]
  end

  test "can iteratively store" do
    nodes = make_pool
    z = List.last(nodes)
    assert {:ok, []} = Knode.lookup(z, "boo")
    Knode.store(z, "boo", "foo")
    assert {:ok, ["foo"]} = Knode.lookup(z, "boo")
  end

end
