# defmodule CryptTest do
#   use ExUnit.Case, async: true
#   alias Exkad.Crypt

#   test "can peel the onion" do
#     me = Crypt.keypair!

#     {a_priv, a} = Crypt.keypair!
#     {b_priv, b} = Crypt.keypair!
#     {c_priv, c} = Crypt.keypair!

#     cyphertext = Crypt.onion("lookup:foo", me, [a, b, c], fn t ->
#       # IO.inspect t
#       t
#     end)

#     a_c = Crypt.peel(cyphertext, a_priv)
#     b_c = Crypt.peel(a_c, b_priv)
#     message = Crypt.peel(b_c, c_priv)

#     IO.inspect message
#     # assert message == "foo"
#   end



# end
