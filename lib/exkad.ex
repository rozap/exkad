# defmodule Exkad do
#   use Application
#   import Supervisor.Spec

#   def start(_type, _args) do
#     child_specs = [
#       worker(Exkad.Node, [])
#     ]

#     opts = [
#       strategy: :one_for_one,
#       name: Exkad.Supervisor
#     ]

#     Supervisor.start_link(child_specs, opts)
#   end
# end
