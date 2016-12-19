defmodule HashTest do
  use ExUnit.Case
  alias Exkad.Hash

  test "can compute distance" do
    assert Hash.distance(<<1>>, <<2>>) == 3
    assert Hash.distance(<<2>>, <<3>>) == 1
  end
end
