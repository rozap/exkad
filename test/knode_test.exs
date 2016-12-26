defmodule KnodeTest do
  use ExUnit.Case
  alias Exkad.{Knode, Hash, Crypt}
  import TestHelper

  @count 8
  @k 16

  # defp make_pool  do
  #   {:ok, sid} = Knode.start_link("seed")
  #   seed = %Knode.Peer{location: sid, id: Hash.hash("seed"), name: "seed"}

  #   peers = "abcdefghijklmnopqrstuvwxyz"
  #   |> String.split("", trim: true)
  #   |> Enum.map(fn pk ->
  #     {:ok, pid} = Knode.start_link(pk)
  #     %Knode.Peer{location: pid, id: Hash.hash(pk), name: pk, k: @k}
  #   end)
  #   Enum.each(peers, fn a ->
  #     Knode.connect(a, seed)
  #   end)

  #   peers
  # end

  # test "can ping" do
  #   a = make("a", @k)
  #   b = make("b", @k)

  #   assert :ok == Knode.connect(a, b)

  #   [b_peer] = List.flatten((Knode.dump(a)).buckets)
  #   [a_peer] = List.flatten((Knode.dump(b)).buckets)

  #   assert b_peer.name == b.name
  #   assert a_peer.name == a.name
  # end

  # test "can store" do
  #   a = make("a", @k)
  #   assert :ok == Knode.put(a, "foo", "bar")
  #   assert Knode.dump(a).data == %{"foo" => "bar"}
  # end

  # test "can iteratively get k closest" do
  #   nodes = make_pool
  #   z = List.last(nodes)
  #   [closest | _] = Knode.lookup_node(z, "a")
  #   assert closest.name == "a"
  # end

  test "can put things on the right node" do
    [a | _] = make_pool(8)
    :timer.sleep(100)
    Knode.store(a, "a", "an a") |> IO.inspect

    :timer.sleep(1500)
    # assert {:error, :not_found} == Knode.get(c, "a")
    # assert {:ok, ["an a"]} == Knode.lookup(c, "a")

    # assert peers_of(a) == ["b", "c"]
    # assert peers_of(b) == ["a", "c"]
    # assert peers_of(c) == ["a", "b"]
  end

  # test "can iteratively store" do
  #   nodes = make_pool
  #   z = List.last(nodes)
  #   assert {:error, _} = Knode.lookup(z, "a")
  #   Knode.store(z, "a", "foo")
  #   assert {:ok, ["foo"]} = Knode.lookup(z, "a")
  # end

end
