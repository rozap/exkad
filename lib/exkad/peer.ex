defmodule Exkad.Peer do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, %{}}
  end

  def handle_call({:ping, from}, _, state) do
    {:reply, :ok, state}
  end

  def ping(me, from) do
    GenServer.call(me, {:ping, from})
  end

end