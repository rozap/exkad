defmodule TestHelper do
  alias Exkad.Knode
  alias Exkad.Knode

  def peers_of(p) do
    Knode.dump(p).buckets
    |> List.flatten
    |> Enum.map(fn %Knode.Peer{name: n} -> n end)
    |> Enum.sort
  end

  def make(pub), do: Knode.new({nil, pub})
end

ExUnit.start()
