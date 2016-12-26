# defmodule Exkad.Router do
#   use GenServer
#   alias Exkad.Knode.Peer
#   alias Exkad.Knode

#   defp forward_request(message, to) do
#     %{
#       "func" => "forward",
#       "params" => [message, Base.encode64(to)]
#     }
#   end

#   defp put_request(key, value) do
#     %{
#       "func" => "put",
#       "params" => [key, value]
#     }
#   end


#   def make_onion(request, {priv, pub}, peers) do
#     [terminal | rest] = Enum.reverse(peers)

#     term_request = request
#     |> Poison.encode!
#     |> Saltpack.encrypt_message([terminal], priv, pub)

#     {onion, first_peer} = Enum.reduce(rest, {term_request, terminal}, fn peer_pubkey, {text, to} ->

#       inner_text = text
#       |> forward_request(to)
#       |> Poison.encode!
#       |> Saltpack.encrypt_message([peer_pubkey], priv, pub)

#       {inner_text, peer_pubkey}
#     end)

#     forward_request(onion, first_peer)
#   end

#   def dispatch(%{"func" => "forward", "params" => [message, to]}, state) do
#     case Knode.k_closest(state.knode, to, 1) do
#       [to_knode] ->

#       _ ->
#         {:error, {:no_node_found, to}}
#     end



#   end


#   def handle_call({:put, key, value, layers}, _, state) do
#     result = with {:ok, peers} <- Knode.sample(state.knode, layers) do
#       sample = Enum.map(peers, fn %Peer{name: pk} -> pk end)

#       result = put_request(key, value)
#       |> make_onion(state.keypair, sample)
#       |> dispatch(state)
#     end

#     {:reply, result, state}
#   end

#   def handle_call({:get, key, layers}, _, state) do
#     {:reply, :ok, state}
#   end

#   def handle_call(:knode, _, state) do
#     {:reply, {:ok, state.knode}, state}
#   end

#   def put(pid, key, value, layers) do
#     GenServer.call(pid, {:put, key, value, layers})
#   end

#   def get(pid, key, layers) do
#     GenServer.call(pid, {:get, key, layers})
#   end

#   def knode(pid) do
#     GenServer.call(pid, :knode)
#   end
# end