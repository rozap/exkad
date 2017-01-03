defmodule IntegrationTest do
  use ExUnit.Case
  alias Exkad.Knode
  import TestHelper

  @count 8
  @k 16

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

    Enum.map(0..8, fn _ ->
      Task.async(fn ->
        {_, e} = Enum.map(0..8, fn i ->
          peer = Enum.random(peers)
          Knode.store(peer, "#{i}", "value_#{i}")

          someone = Enum.random(peers)
          Knode.lookup(someone, "#{i}")
        end)
        |> Enum.partition(fn {:ok, _} -> true; {:error, _} -> false end)

        assert length(e) == 0
      end)
    end)
    |> Enum.map(fn t -> Task.await(t, 60_000) end)
  end


end
