# defmodule RouterTest do
#   use ExUnit.Case
#   alias Exkad.{Knode, Router, Crypt}
#   import TestHelper

#   @count 8
#   @k 16

#   defp make_seed() do
#     {:ok, pid} = Router.start_link(Crypt.keypair!, @k)
#     pid
#   end

#   setup do
#     seed_router = make_seed
#     with {:ok, seed} <- Router.knode(seed_router) do
#       {:ok, pid} = Router.start_link(Crypt.keypair!, @k, seed)
#       Enum.each(0..@count, fn _ ->
#         Router.start_link(Crypt.keypair!, @k, seed)
#       end)
#       %{router: pid}
#     end
#   end

#   test "can generate an onion" do
#     me = Crypt.keypair!

#     {a_priv, a} = Crypt.keypair!
#     {b_priv, b} = Crypt.keypair!

#     a64 = Base.encode64(a)
#     b64 = Base.encode64(b)

#     %{
#       "func" => "forward",
#       "params" => [a_msg, ^a64]
#     } = Router.make_onion("lookup:foo", me, [a, b])

#     %{
#       "func" => "forward",
#       "params" => [b_msg, ^b64]
#     } = a_msg
#     |> Saltpack.open_message(a_priv)
#     |> Poison.decode!

#     orig = Saltpack.open_message(b_msg, b_priv) |> Poison.decode!

#     assert orig == "lookup:foo"
#   end

#   test "can put something", %{router: r} do
#     Router.put(r, "some_key", "some_value", 5)
#   end



# end
