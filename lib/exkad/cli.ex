defmodule Exkad.Cli do
  alias Exkad.{Knode, Hash}

  @mutation 10

  defp make(pk, k) do
    {:ok, pid} = Knode.start_link(pk)
    %Knode.Peer{location: pid, id: Hash.hash(pk), name: pk, k: k}
  end

  defmacro timeit(f) do
    quote do
      s = :erlang.system_time
      r = unquote(f)
      e = :erlang.system_time

      {e - s, r}
    end
  end


  defp fitness(write, read, success) when success >= 0.999999 do
    1_000_000_000_000_000 / (write * read)
  end
  defp fitness(write, read, success), do: 0


  defp run(peers, parallelism, store_count) do
    {w, r, s} = Enum.map(1..parallelism, fn _ ->
      Task.async(fn ->
        {o, e} = Enum.map(0..store_count, fn i ->
          peer = Enum.random(peers)

          {store_time, _} = timeit(Knode.store(peer, "#{i}", "value_#{i}"))

          someone = Enum.random(peers)
          {lookup_time, lookup_res} = timeit(Knode.lookup(someone, "#{i}"))

          {store_time, lookup_time, lookup_res}
        end)
        |> Enum.partition(fn
          {_, _, {:ok, _}} -> true
          {_, _, {:error, _}} -> false
        end)

        avg_w = (Enum.map(o, fn {w, _, _} -> w end)
                |> Enum.sum) / length(o)

        avg_r = (Enum.map(o, fn {_, r, _} -> r end)
                |> Enum.sum) / length(o)


        {avg_w, avg_r, length(o) / (length(o) + length(e))}
      end)
    end)
    |> Enum.map(fn t ->
      Task.await(t, :infinity)
    end)
    |> Enum.reduce({0, 0, 0}, fn {w, r, s}, {wa, ra, sa} ->
      {wa + w, ra + r, sa + s}
    end)

    avg_w = w / parallelism
    avg_r = r / parallelism
    avg_s = s / parallelism

    fitness(avg_w, avg_r, avg_s)
  end

  defp generation(count, k) do
    seed = make("seed", k)

    peers = Enum.map(0..count, fn i -> make("#{i}", k) end)

    Enum.each(peers, fn a ->
      Knode.connect(a, seed)
      :timer.sleep(5)
    end)

    peers
  end

  def rand(mk, mk) do
    Enum.random(trunc(mk / 2)..trunc(mk * 2))
  end
  def rand(mk, fk) do
    mk = max(0, mk)
    fk = max(0, fk)

    if :rand.uniform(100) < @mutation do
      Enum.random(trunc(min(mk, fk) / 2)..trunc(max(mk, fk) * 4))
    else
      Enum.random(mk..fk)
    end
  end

  def offspring(mk, fk, pk, 32) do
    IO.puts "Came up with #{mk} #{fk} #{pk}"
  end
  def offspring(mk, fk, p_k, iterations) do
    [{a_k, a_f}, {b_k, b_f}] = Enum.map(0..8, fn _ ->
      Task.async(fn ->
        k = rand(mk, fk)
        fitness = generation(3, k) |> run(4, 256)
        {k, fitness}
      end)
      |> Task.await(:infinity)

    end)
    |> Enum.sort_by(fn {_, f} -> -f end)
    |> Enum.take(2)

    p_k = trunc((0.25 * p_k) + (0.75 * ((mk + fk) / 2)))
    IO.puts "Gen #{iterations}, #{a_k} & #{b_k} & #{p_k} | fitness #{a_f} #{b_f}"
    offspring(a_k, b_k, p_k, iterations + 1)
  end

  def main(args) do
    IO.puts "Starting"
    case OptionParser.parse(args) do
      {parsed, args, _} ->

        offspring(2, 16, 8, 0)
    end
  end
end