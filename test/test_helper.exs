defmodule TestHelper do
  alias Exkad.{Knode, Hash, Crypt}

  def peers_of(p) do
    Knode.dump(p).buckets
    |> List.flatten
    |> Enum.map(fn %Knode.Peer{name: n} -> n end)
    |> Enum.sort
  end

  def make_pool(count)  do
    seed = Knode.new(Crypt.keypair!)

    peers = Enum.map(0..count, fn i -> Knode.new(Crypt.keypair!) end)

    Enum.each(peers, fn a ->
      Knode.connect(a, seed)
    end)

    [seed | peers]
  end

end

ExUnit.start()
