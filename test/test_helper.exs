defmodule TestHelper do
  alias Exkad.Knode

  def peers_of(p) do
    Knode.dump(p).buckets
    |> List.flatten
    |> Enum.map(fn %Knode.Peer{name: n} -> n end)
    |> Enum.sort
  end

  def make(pub), do: Knode.new({nil, pub}, [])
end

dir = Application.get_env(:exkad, :data)
File.rm_rf!(dir)
File.mkdir_p!(dir)

ExUnit.start(timeout: 60_000)
