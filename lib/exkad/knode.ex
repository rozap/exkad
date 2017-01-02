defmodule Exkad.Knode do
  use GenServer
  import Exkad.Hash
  require Logger
  alias Exkad.Connection

  @k 16
  @replication 1

  defmodule State do
    defstruct [:bitlist,
      :me,
      :keypair,
      buckets: [],
      data: %{}
    ]
  end

  defmodule Peer do
    defstruct [:location, :id, :name, :k]
  end

  defmodule TCPPeer do
    defstruct [:ip, :port, :id, :name, :k]
  end

  def new({_priv, pub} = keypair, opts) do
    {:ok, pid} = start_link(keypair, opts)

    k = Keyword.get(opts, :k, @k)
    %Peer{location: pid, id: hash(pub), name: pub, k: k}
  end

  def start_link(keypair, opts) do
    GenServer.start_link(__MODULE__, [keypair, opts], [])
  end

  def init([{_priv, pub} = keypair, opts]) do
    id = hash(pub)
    name = pub
    k = Keyword.get(opts, :k, @k)

    with {:ok, external_me, internal_me} <- my_identity(id, name, k, Enum.into(opts, %{})),
      :ok = Connection.start_link(external_me, internal_me) do

      state = %State{
        me: external_me,
        keypair: keypair,
        buckets: Enum.map(0..bit_size(external_me.id), fn _ -> [] end)
      }
      {:ok, state}      
    end
  end

  defp my_identity(id, name, k, %{tcp: tcp_opts}) do
    case Enum.into(tcp_opts, %{}) do
      %{port: port, ip: ip} -> 
        external_me = %TCPPeer{
          ip: ip, 
          port: port,
          name: name, 
          id: id,
          k: k
        }
        {:ok, internal_me, _} = my_identity(id, name, k, nil)
        {:ok, external_me, internal_me}
      invalid -> {:error, {"Invalid TCP opts", invalid}}
    end
  end
  defp my_identity(id, name, k, _) do
    me = %Peer{location: self, id: id, name: name, k: k}
    {:ok, me, me}
  end


  defp prefix_length(<<same::size(1), a_rest::bitstring>>, <<same::size(1), b_rest::bitstring>>) do
    1 + prefix_length(a_rest, b_rest)
  end
  defp prefix_length(_, _), do: 0

  defp add_peer(:nobody, state), do: state
  defp add_peer(%Peer{} = me, %State{me: me} = state), do: state
  defp add_peer(peer, state) do
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
      p -> Connection.k_closest(p, key, refs, me)
    end)
    log_refs("k_closest_of_#{length(peers)}_done", refs, me)

    next_gen = peers_k_closest
    |> Enum.sort_by(fn peer -> distance(peer.id, h) end)
    |> Enum.take(me.k)

    Enum.each(peers_k_closest, fn peer -> add(me, peer) end)

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

  def handle_call({:ping, from_peer}, _, state) do
    state = add_peer(from_peer, state)
    {:reply, :ok, state}
  end

  def handle_call({:add, peer}, _, state) do
    state = add_peer(peer, state)
    {:reply, :ok, state}
  end


  def handle_call({:connect, peer} , _, state) do
    refs = [make_ref]
    log_refs(:connect, refs, state.me)
    state = add_peer(peer, state)

    me = state.me
    Task.async(fn ->
      {:error, {:not_found, _}} = lookup(me, me.id)

      case Connection.ping(peer, me) do
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

  def handle_call(:dump, _, state) do
    {:reply, state, state}
  end

  def lookup_node(%Peer{} = me, pk) do
    refs = [make_ref]
    log_refs(:lookup_node, refs, me)

    Connection.k_closest(me, pk, refs, :nobody)
    |> get_closer(pk, me, refs)
  end

  def lookup(%Peer{} = me, key) do
    refs = [make_ref]
    log_refs(:lookup, refs, me)

    {oks, errors} = Connection.k_closest(me, key, refs, :nobody)
    |> get_closer(key, me, refs)
    |> Enum.map(fn
      p -> {p, Connection.get(p, key)}
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

  def store(%Peer{} = me, key, value, replication \\ @replication) do
    refs = [make_ref]
    log_refs(:store, refs, me)

    Connection.k_closest(me, key, refs, :nobody)
    |> get_closer(key, me, refs)
    |> Enum.take(replication)
    |> Enum.map(fn peer ->
        Connection.put(peer, key, value, refs)
    end)
  end


  def add(%Peer{} = me, peer) do
    GenServer.call(me.location, {:add, peer})
  end

  # Not used?
  def connect(%Peer{} = me, %Peer{} = me), do: :ok
  def connect(%Peer{location: me} = me, %Peer{location: me}) do
    raise RuntimeError, message: "Peers do not match but locations match?"
  end
  def connect(%Peer{} = me, p) do
    GenServer.call(me.location, {:connect, p})
  end

  def dump(%Peer{} = me) do
    GenServer.call(me.location, :dump)
  end
end