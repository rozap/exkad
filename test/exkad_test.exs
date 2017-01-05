defmodule ExkadTest do
  use ExUnit.Case, async: true
  alias Exkad.Knode

  defp random_port() do
    Enum.random(5000..10_000)
  end


  test "can build a network" do
    p = random_port()
    _ = Knode.new({nil, "s"}, tcp: [port: p, ip: "localhost"])
    {:ok, s} = Knode.seed("s", tcp: [port: p, ip: "localhost"])

    {:ok, _} = Exkad.start(:supervisor, [
      {{nil, UUID.uuid4}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, UUID.uuid4}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, UUID.uuid4}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, UUID.uuid4}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, UUID.uuid4}, [tcp: [port: random_port(), ip: "localhost"], seed: s]}
    ])

    :timer.sleep(50) # Let seeds settle

    assert Exkad.store("a", "a value") == [:ok]
    assert Exkad.lookup("a") == {:ok, ["a value"]}

    assert Exkad.store("a", "another value") == [:ok]
    {:ok, another} = Exkad.lookup("a")

    assert MapSet.new(another) == MapSet.new(["a value", "another value"])

  end
end
