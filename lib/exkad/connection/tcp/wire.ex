defmodule Exkad.Tcp.Wire do
  @socket_timeout 2000
  @size 1024 * 5
  @newline 10

  def read_chars(<<@newline, _::binary>>, acc) do
    with {:ok, bin} <- acc
    |> :erlang.list_to_binary
    |> Base.decode64 do 
      {:ok, :erlang.binary_to_term(bin)}
    end
  end
  def read_chars(<<x, rest::binary>>, acc) do
    read_chars(rest, [acc, x])
  end
  def read_chars(_, acc) do
    {:more, acc}
  end

  def do_receive(sock, ioacc \\ []) do
    case :gen_tcp.recv(sock, 0) do
      {:ok, bin} -> 
        case read_chars(bin, ioacc) do
          {:more, acc} -> do_receive(sock, acc)
          result -> result
        end
      err -> err
    end
  end

  def serialize!(term) do
    payload = term
    |> :erlang.term_to_binary
    |> Base.encode64

    payload <> "\n"
  end

end