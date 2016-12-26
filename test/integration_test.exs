# defmodule IntegrationTest do
#   use ExUnit.Case
#   alias Exkad.{Knode, Hash}
#   import TestHelper

#   @count 16

#   test "can put and get stuff from the network" do
#     peers = make_pool(@count)

#     {o, e} = Enum.map(0..32, fn i ->
#       peer = Enum.random(peers)
#       Knode.store(peer, "#{i}", "value_#{i}")

#       someone = Enum.random(peers)
#       Knode.lookup(someone, "#{i}")
#     end)
#     |> Enum.partition(fn {:ok, _} -> true; {:error, _} -> false end)

#     assert length(e) == 0
#     assert length(o) == 33
#   end


# end
