defmodule Exkad.Introspect do
  alias Exkad.Knode.Peer
  alias Exkad.Knode

  defp peers_of(p) do
    Knode.dump(p).buckets
    |> List.flatten
    |> Enum.dedup
  end

  def vis(%Peer{} = p) do
    visualize(peers_of(p))
  end

  def visualize(peers) do
    s = Enum.flat_map(peers, fn p ->
      Enum.map(peers_of(p), fn pp ->
        {p.name, pp.name}
      end)
    end)
    |> Enum.uniq
    |> to_dot

    File.write!("out.dot", s)
    System.cmd("dot", ["-Tpng", "out.dot", "-o", "out.png"])
  end

  defp to_dot(nodes) do
    "digraph G {\n#{node_s(nodes)}}"
  end

  defp node_s([]), do: ""
  defp node_s([{a, b} | rest]) do
    "  " <> a <> " -> " <> b <> ";\n" <> node_s(rest)
  end
end