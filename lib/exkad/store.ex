defmodule Exkad.Store do
  use GenServer
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, [name])
  end

  def init([name]) do
    dir = Application.get_env(:exkad, :data)
    File.mkdir_p!(dir)

    {:ok, db} = dir
    |> Path.join(name)
    |> :binary.bin_to_list
    |> :eleveldb.open([create_if_missing: true])

    {:ok, %{
      name: name,
      db: db
      }}
  end

  defp do_get(key, state) do
    case :eleveldb.get(state.db, key, []) do
      :not_found   -> {:ok, []}
      {:ok, value} -> {:ok, :erlang.binary_to_term(value)}
    end
  end

  def handle_call({:put, key, value}, _, state) do
    Logger.debug("Putting #{key} on #{state.name}")
    {:ok, existing} = do_get(key, state)
    serialized = :erlang.term_to_binary([value | existing])
    :eleveldb.put(state.db, key, serialized, [])
    {:reply, :ok, state}
  end

  def handle_call({:get, key}, _, state) do
    Logger.debug("Getting #{key} on #{state.name}")
    result = do_get(key, state)
    {:reply, result, state}
  end

  def put(store, key, value) do
    GenServer.call(store, {:put, key, value})
  end

  def get(store, key) do
    GenServer.call(store, {:get, key})
  end
end