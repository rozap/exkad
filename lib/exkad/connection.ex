defprotocol Exkad.Connection do
  def start_link(peer, local)

  def ping(peer, from)

  def put(peer, key, value)

  def get(peer, key)

  def k_closest(peer, key, from \\ :nobody)
end