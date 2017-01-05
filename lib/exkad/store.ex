defmodule Exkad.Store do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, [name])
  end

  def init([name]) do
    {:ok, db} = Application.get_env(:exkad, :data)
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
    {:ok, existing} = do_get(key, state)
    serialized = :erlang.term_to_binary([value | existing])
    :eleveldb.put(state.db, key, serialized, [])
    {:reply, :ok, state}
  end

  def handle_call({:get, key}, _, state) do
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