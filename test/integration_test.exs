defmodule IntegrationTest do
  use ExUnit.Case
  alias Exkad.{Knode, Hash}
  import TestHelper

  @count 32
  @k 16

  defp make(pk) do
    {:ok, pid} = Knode.start_link(pk)
    %Knode.Peer{location: pid, id: Hash.hash(pk), name: pk, k: @k}
  end

  defp make_pool  do
    seed = make("seed")

    peers = Enum.map(0..@count, fn i -> make("#{i}") end)

    Enum.each(peers, fn a ->
      Knode.connect(a, seed)
    end)

    peers
  end

  test "can put and get stuff from the network" do
    peers = make_pool

    {o, e} = Enum.map(0..100, fn i ->
      peer = Enum.random(peers)
      Knode.store(peer, "#{i}", "value_#{i}")

      someone = Enum.random(peers)
      Knode.lookup(someone, "#{i}")
    end)
    |> Enum.partition(fn {:ok, _} -> true; {:error, _} -> false end)

    IO.puts "Ratio is #{length(o)} #{length(e)}"
  end


end
