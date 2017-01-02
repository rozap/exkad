defprotocol Exkad.Connection do
  def start_link(peer, local)

  def ping(peer, from)

  def put(peer, key, value, refs \\ [])

  def get(peer, key, refs \\ [])

  def k_closest(peer, key, refs \\ [], from \\ :nobody)
end