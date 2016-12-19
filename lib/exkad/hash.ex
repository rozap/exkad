defmodule Exkad.Hash do
  use Bitwise

  @min_id Enum.map(0..32, fn _ -> 0 end)
  @max_id Enum.map(0..32, fn _ -> 255 end)

  def hash(loc) do
    bin = :erlang.term_to_binary(loc)
    :crypto.hash(:md5, bin)
  end

  defp to_num(id) do
    :erlang.bitstring_to_list(id)
    |> Enum.reduce(0, fn byte, n ->
      (n <<< 8) + byte
    end)
  end

  def max_id, do: @max_id
  def min_id, do: @min_id

  def distance(a_id, b_id) do
    Enum.zip(
      :erlang.bitstring_to_list(a_id),
      :erlang.bitstring_to_list(b_id)
    )
    |> Enum.reduce(0, fn {a, b}, n ->
      (n <<< 8) + (a ^^^ b)
    end)
  end


end