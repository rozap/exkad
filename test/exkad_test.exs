defmodule ExkadTest do
  use ExUnit.Case
  alias Exkad.Knode

  defp random_port() do
    Enum.random(5000..10_000)
  end


  test "can build a network" do
    p = random_port()
    _ = Knode.new({nil, "s"}, tcp: [port: p, ip: "localhost"])
    {:ok, s} = Knode.seed("s", tcp: [port: p, ip: "localhost"])

    {:ok, _} = Exkad.start(:supervisor, [
      {{nil, "a"}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, "b"}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, "c"}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, "d"}, [tcp: [port: random_port(), ip: "localhost"], seed: s]},
      {{nil, "e"}, [tcp: [port: random_port(), ip: "localhost"], seed: s]}
    ])

    :timer.sleep(50) #Let seeds settle

    assert Exkad.store("a", "a value") == [:ok]
    assert Exkad.lookup("a") == {:ok, ["a value"]}
  end
end
