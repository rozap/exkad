defmodule TestHelper do
  alias Exkad.Knode

  def peers_of(p) do
    Knode.dump(p).buckets
    |> List.flatten
    |> Enum.map(fn %Knode.Peer{name: n} -> n end)
    |> Enum.sort
  end
end

ExUnit.start()
