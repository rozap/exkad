defmodule Exkad.Knode do
  use GenServer
  import Exkad.Hash
  require Logger

  @k 16
  @replication 1
  @layers 5

  defmodule State do
    defstruct [:bitlist,
      :me,
      buckets: [],
      data: %{}
    ]
  end

  defmodule Peer do
    defstruct [:location, :id, :name, :k, :keypair]
  end

  def start_link(keypair, k) do
    GenServer.start_link(__MODULE__, [keypair, k], [])
  end


  def new(keypair, k \\ @k) do
    {:ok, pid} = start_link(keypair, k)

    {_, pub_key} = keypair
    %Peer{location: pid, id: hash(pub_key), name: pub_key, k: k, keypair: keypair}
  end

  def init([{_, pub_key} = keypair, k]) do
    id = hash(pub_key)
    state = %State{
      me: %Peer{
        location: self,
        id: id,
        name: pub_key,
        k: k,
        keypair: keypair
      },
      buckets: Enum.map(0..bit_size(id), fn _ -> [] end)
    }
    {:ok, state}
  end

  defp prefix_length(<<same::size(1), a_rest::bitstring>>, <<same::size(1), b_rest::bitstring>>) do
    1 + prefix_length(a_rest, b_rest)
  end
  defp prefix_length(_, _), do: 0

  defp add_peer(:nobody, state), do: state
  defp add_peer(%Peer{} = me, %State{me: me} = state), do: state
  defp add_peer(%Peer{} = peer, state) do
    position = prefix_length(state.me.id, peer.id)

    # IO.inspect {:position, position}
    buckets = Enum.with_index(state.buckets)
    |> Enum.map(fn
      {b, ^position} -> Enum.take(Enum.uniq([peer | b]), state.me.k)
      {b, _}         -> b
    end)

    %{state | buckets: buckets}
  end

  defp get_k_closest(key, %State{buckets: buckets, me: me}) do
    candidates = buckets
    |> List.flatten

    top_k_from([me | candidates], key, me.k)
  end

  defp top_k_from(peers, key, k) do
    h = hash(key)

    peers
    |> Enum.sort_by(fn peer -> distance(peer.id, h) end)
    |> Enum.take(k)
  end

  defp get_closer(_, _, me, refs, 5) do
    log_refs(:max_iter, refs, me)
    raise RuntimeError, message: "Hit max iter"
  end
  defp get_closer(_, _, %Peer{k: nil}, _, _) do
    raise RuntimeError, message: "nil k"
  end
  defp get_closer(peers, key, me, refs, iter) do
    h = hash(key)

    log_refs("k_closest_of_#{length(peers)}", refs, me)
    peers_k_closest = Enum.flat_map(peers, fn
      p -> k_closest(p, key, refs, me)
    end)
    log_refs("k_closest_of_#{length(peers)}_done", refs, me)

    next_gen = peers_k_closest
    |> Enum.sort_by(fn peer -> distance(peer.id, h) end)
    |> Enum.take(me.k)

    Enum.each(peers_k_closest, fn peer ->
      add(me, peer)
    end)

    best = Enum.min_by(peers, fn p -> distance(p.id, h) end)
    best_dist = distance(best.id, h)

    has_better = Enum.any?(next_gen, fn next ->
      distance(next.id, h) < best_dist
    end)

    if has_better do
      (peers ++ next_gen)
      |> Enum.uniq
      |> top_k_from(key, me.k)
      |> get_closer(key, me, refs, iter + 1)
    else
      peers
    end
  end
  defp get_closer(peers, key, me, refs) do
    get_closer(peers, key, me, refs, 0)
  end

  defp put_in_state(key, value, state) do
    {struct(state, data: Map.put(state.data, key, value)), :ok}
  end

  defp get_in_state(key, state) do
    case Map.get(state.data, key, :not_found) do
      :not_found -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  defp log_refs(label, refs, me) do
    s = refs
    |> Enum.map(fn r ->
      hash(r)
      |> :erlang.bitstring_to_list
      |> Enum.map(&(:io_lib.format("~2.16.0b", [&1])))
      |> List.flatten
      |> to_string
      |> String.slice(0..8)
    end)
    |> Enum.join("|")
    Logger.debug("#{label} :: #{s} :: #{inspect me.name} #{inspect me.location}")
  end

  def handle_call({:ping, %Peer{} = from_peer}, _, state) do
    state = add_peer(from_peer, state)
    {:reply, :ok, state}
  end

  def handle_call({:add, %Peer{} = peer}, _, state) do
    state = add_peer(peer, state)
    {:reply, :ok, state}
  end


  def handle_call({:connect, %Peer{} = peer, k} , _, state) do
    refs = [make_ref]
    log_refs(:connect, refs, state.me)
    state = add_peer(peer, state)

    me = state.me
    Task.async(fn ->
      {:error, {:not_found, _}} = lookup(me, me.id)

      case ping(peer, me) do
        :ok ->
          log_refs(:connect_done, refs, me)
        reason ->
          Logger.error("Bootstrap ping failed: #{reason}")
      end
    end)

    {:reply, :ok, state}
  end

  def handle_call({:put, key, value, refs}, _, state) do
    log_refs(:put, refs, state.me)
    {state, result} = put_in_state(key, value, state)
    {:reply, result, state}
  end

  def handle_call({:get, key, refs}, _, state) do
    log_refs(:get, refs, state.me)
    result = get_in_state(key, state)
    {:reply, result, state}
  end

  def handle_call({:k_closest, key, from, refs}, _, state) do
    log_refs(:k_closest, refs, state.me)
    state = add_peer(from, state)
    closest = get_k_closest(key, state)
    log_refs(:k_closest_done, refs, state.me)
    {:reply, closest, state}
  end

  def handle_call({:sample, quantity}, _, %State{buckets: b} = state) do
    sample = List.flatten(b)
    |> Enum.shuffle
    |> Enum.take(quantity)

    reply = if length(sample) < quantity do
      {:error, :insufficient_peers}
    else
      {:ok, sample}
    end
    {:reply, reply, state}
  end

  def handle_call(:dump, _, state) do
    {:reply, state, state}
  end

  def handle_cast({:store, key, value, replication}, state) do
    refs = [make_ref]
    log_refs(:store, refs, state.me)

    IO.inspect {:store, key, value}

    get_k_closest(key, state)
    |> get_closer(key, state.me, refs)
    |> Enum.take(replication)
    |> Enum.map(fn peer ->
        put(peer, key, value, refs)
    end)

    {:noreply, state}
  end

  def handle_cast({:forward, message, peer_bin}, state) do
    res = with {:ok, %Peer{} = peer} <- decode_peer(peer_bin) do
      boxed_request(peer, message)
    end

    {:noreply, state}
  end

  def handle_cast({:boxed_request, cyphertext}, state) do
    spawn_link(fn ->
      open_and_dispatch(cyphertext, state.me)
    end)
    {:noreply, state}
  end

  def boxed_request(%Peer{} = peer, cyphertext) do
    GenServer.cast(peer.location, {:boxed_request, cyphertext})
  end

  def sample(%Peer{} = peer, quantity) do
    GenServer.call(peer.location, {:sample, quantity})
  end

  def ping(%Peer{} = peer, %Peer{} = from) do
    GenServer.call(peer.location, {:ping, from})
  end

  def put(%Peer{} = me, key, value, refs \\ []) do
    refs = [make_ref | refs]
    GenServer.call(me.location, {:put, key, value, refs})
  end

  def get(%Peer{} = peer, key, refs \\ []) do
    refs = [make_ref | refs]
    GenServer.call(peer.location, {:get, key, refs})
  end

  def k_closest(%Peer{} = me, key, refs \\ [], from \\ :nobody) do
    refs = [make_ref | refs]
    GenServer.call(me.location, {:k_closest, key, from, refs}, 1000)
  end

  def lookup_node(%Peer{} = me, pk) do
    refs = [make_ref]
    log_refs(:lookup_node, refs, me)

    k_closest(me, pk, refs)
    |> get_closer(pk, me, refs)
  end

  def lookup(%Peer{} = me, key) do
    refs = [make_ref]
    log_refs(:lookup, refs, me)

    {oks, errors} = k_closest(me, key, refs)
    |> get_closer(key, me, refs)
    |> Enum.map(fn
      p -> {p, get(p, key)}
    end)
    |> Enum.partition(fn
      {_peer, {:ok, _}} -> true
      {_peer, {:error, _}} -> false
    end)

    case oks do
      [] -> {:error, {:not_found, errors}}
      _ ->
        results = Enum.map(oks, fn {_, {:ok, v}} -> v end)
        |> Enum.uniq

        {:ok, results}
    end
  end

  def store(%Peer{} = me, key, value, replication \\ @replication, layers \\ 5) do
    result = with {:ok, sample} <- sample(me, layers) do
      result = store_request(key, value, replication)
      |> make_onion(me, sample)
      |> do_dispatch(me)
    end
  end

  def add(%Peer{} = me, %Peer{} = peer) do
    GenServer.call(me.location, {:add, peer})
  end

  defp open_and_dispatch(cyphertext, me) do
    {priv, pub} = me.keypair
    with {:ok, msg} <- Poison.decode(Saltpack.open_message(cyphertext, priv)) do
      do_dispatch(msg, me)
    end
  end

  defp do_dispatch(%{"func" => "forward", "params" => [forwardee_message, forwardee]}, to) do
    IO.inspect {:dispatching, forwardee}
    GenServer.cast(to.location, {:forward, forwardee_message, forwardee})
  end

  defp do_dispatch(%{"func" => "store", "params" => [key, value, replication]}, me) do
    refs = [make_ref]
    log_refs(:store, refs, me)

    IO.inspect {:storing, key, value}

    k_closest(me, key, refs)
    |> get_closer(key, me, refs)
    |> Enum.take(replication)
    |> Enum.map(fn peer ->
        put(peer, key, value, refs)
    end)
  end
  # Onioning
  #
  #
  defp forward_request(message, %Peer{} = p) do
    %{
      "func" => "forward",
      "params" => [message, encode_peer!(p)]
    }
  end

  defp store_request(key, value, replication) do
    %{
      "func" => "store",
      "params" => [key, value, replication]
    }
  end

  def encode_peer!(%Peer{} = p) do
    Base.encode64(:erlang.term_to_binary(p))
  end

  def decode_peer(b64)do
    with {:ok, bin} <- Base.decode64(b64) do
      {:ok, :erlang.binary_to_term(bin)}
    end
  end

  def encrypt_message(message, %Peer{keypair: {priv, pub}} = _from, %Peer{name: to_pk} = to) do
    message
    |> Poison.encode!
    |> Saltpack.encrypt_message([to_pk], priv, pub)
  end

  def make_onion(request, %Peer{} = me, peers) do
    [terminal | rest] = Enum.reverse(peers)

    term_request = encrypt_message(request, me, terminal)
    {onion, first_peer} = Enum.reduce(rest, {term_request, terminal}, fn prev_peer, {text, %Peer{} = to} ->

      inner_text = text
      |> forward_request(to)
      |> encrypt_message(me, prev_peer)

      {inner_text, prev_peer}
    end)

    forward_request(onion, first_peer)
  end

  # Not used?
  def connect(%Peer{} = me, %Peer{} = me), do: :ok
  def connect(%Peer{location: me} = me, %Peer{location: me}) do
    raise RuntimeError, message: "Peers do not match but locations match?"
  end
  def connect(%Peer{} = me, %Peer{} = p, k \\ @k) do
    GenServer.call(me.location, {:connect, p, k})
  end

  def dump(%Peer{} = me) do
    GenServer.call(me.location, :dump)
  end

end