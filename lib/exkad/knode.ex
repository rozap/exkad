defmodule Exkad.Knode do
  use GenServer
  import Exkad.Hash
  require Logger
  alias Exkad.{Store, Connection}

  @k 16
  @replication 1

  defmodule State do
    defstruct [:bitlist,
      :me,
      :local_me,
      :keypair,
      :k,
      :store,
      buckets: [],
      data: %{}
    ]
  end

  defmodule Peer do
    defstruct [:location, :id, :name, :k]
  end

  defmodule TCPPeer do
    defstruct [:ip, :port, :id, :name]
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
    Logger.info("Exkad.Knode is starting with name #{pub}")

    id = hash(pub)
    name = pub
    k = Keyword.get(opts, :k, @k)

    with {:ok, external_me, local_me} <- my_identity(id, name, k, Enum.into(opts, %{})),
      :ok = Connection.start_link(external_me, local_me) do

      {:ok, store} = Store.start_link(name)

      state = %State{
        me: external_me,
        local_me: local_me,
        k: k,
        keypair: keypair,
        buckets: Enum.map(0..bit_size(external_me.id), fn _ -> [] end),
        store: store
      }

      :pg2.create(:exkad)
      :pg2.join(:exkad, self)

      case Keyword.get(opts, :seed) do
        nil -> :ok
        seed -> spawn_link(fn ->
          Logger.info("Connecting #{name} to #{seed.name}")
          connect(local_me, seed)
        end)
      end

      {:ok, state}
    end
  end

  defp my_identity(id, name, k, %{tcp: tcp_opts}) do
    with {:ok, external_me} <- tcp_peer_of(id, name, tcp_opts) do
      {:ok, local_me, _} = my_identity(id, name, k, nil)
      {:ok, external_me, local_me}
    end
  end
  defp my_identity(id, name, k, _) do
    me = %Peer{location: self, id: id, name: name, k: k}
    {:ok, me, me}
  end

  defp tcp_peer_of(id, name, tcp_opts) do
    case Enum.into(tcp_opts, %{}) do
      %{port: port, ip: ip} ->
        peer = %TCPPeer{
          ip: ip,
          port: port,
          name: name,
          id: id
        }
        {:ok, peer}
      invalid ->
        {:error, {"Invalid TCP opts", invalid}}
    end
  end

  def seed(name, %{tcp: tcp_opts}) do
    id = hash(name)
    tcp_peer_of(id, name, tcp_opts)
  end
  def seed(name, opts) when is_list(opts) do
    seed(name, Enum.into(opts, %{}))
  end

  defp prefix_length(<<same::size(1), a_rest::bitstring>>, <<same::size(1), b_rest::bitstring>>) do
    1 + prefix_length(a_rest, b_rest)
  end
  defp prefix_length(_, _), do: 0

  defp add_peer(:nobody, state), do: state
  defp add_peer(%Peer{} = me, %State{me: me} = state), do: state
  defp add_peer(peer, state) do
    position = prefix_length(state.me.id, peer.id)

    buckets = Enum.with_index(state.buckets)
    |> Enum.map(fn
      {b, ^position} -> Enum.take(Enum.uniq([peer | b]), state.k)
      {b, _}         -> b
    end)

    %{state | buckets: buckets}
  end

  defp get_k_closest(key, %State{buckets: buckets, me: me, k: k}) do
    candidates = buckets
    |> List.flatten

    top_k_from([me | candidates], key, k)
  end

  defp top_k_from(peers, key, k) do
    h = hash(key)

    peers
    |> Enum.sort_by(fn peer -> distance(peer.id, h) end)
    |> Enum.take(k)
  end

  defp get_closer(_, _, me, 5) do
    raise RuntimeError, message: "Hit max iter"
  end
  defp get_closer(_, _, %Peer{k: nil}, _) do
    raise RuntimeError, message: "nil k"
  end
  defp get_closer(peers, key, me, iter) do
    h = hash(key)

    peers_k_closest = Enum.flat_map(peers, fn
      p -> Connection.k_closest(p, key, me)
    end)

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
      |> get_closer(key, me, iter + 1)
    else
      peers
    end
  end
  defp get_closer(peers, key, me) do
    get_closer(peers, key, me, 0)
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
    state = add_peer(peer, state)

    {:reply, :ok, state}
  end

  def handle_call({:put, key, value}, _, state) do
    result = Store.put(state.store, key, value)
    {:reply, result, state}
  end

  def handle_call({:get, key}, _, state) do
    result = Store.get(state.store, key)
    {:reply, result, state}
  end

  def handle_call({:k_closest, key, from}, _, state) do
    state = add_peer(from, state)
    closest = get_k_closest(key, state)
    {:reply, closest, state}
  end

  def handle_call(:dump, _, state) do
    {:reply, state, state}
  end

  def handle_call(:peer_of, _, state) do
    {:reply, {:ok, state.local_me}, state}
  end

  def lookup_node(me, pk) do
    Connection.k_closest(me, pk, :nobody)
    |> get_closer(pk, me)
  end

  def lookup(me, key) do
    {oks, errors} = Connection.k_closest(me, key, :nobody)
    |> get_closer(key, me)
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
        results = Enum.flat_map(oks, fn {_, {:ok, v}} -> v end)
        |> Enum.uniq

        {:ok, results}
    end
  end

  def store(%Peer{} = me, key, value, replication \\ @replication) do
    Connection.k_closest(me, key, :nobody)
    |> get_closer(key, me)
    |> Enum.take(replication)
    |> Enum.map(fn peer -> Connection.put(peer, key, value) end)
  end


  def add(%Peer{} = me, peer) do
    GenServer.call(me.location, {:add, peer})
  end

  # Not used?
  def connect(%Peer{} = me, %Peer{} = me), do: :ok
  def connect(%Peer{location: me} = me, %Peer{location: me}) do
    raise RuntimeError, message: "Peers do not match but locations match?"
  end
  def connect(%Peer{} = me, peer) do
    :ok = GenServer.call(me.location, {:connect, peer})

    {:ok, []} = lookup(me, me.id)

    case Connection.ping(peer, me) do
      :ok ->
        :ok
      reason ->
        Logger.error("Bootstrap ping failed: #{reason}")
        :error
    end
  end

  def dump(%Peer{} = me) do
    GenServer.call(me.location, :dump)
  end

  def peer_of(pid) do
    GenServer.call(pid, :peer_of)
  end
end