defmodule Exkad.Crypt do


  # {priv, pub}
  def keypair! do
    Saltpack.new_key_pair
  end

end