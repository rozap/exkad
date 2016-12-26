defmodule Exkad.Cli do
  # alias Exkad.{Knode, Hash}

  def main(args) do
    case OptionParser.parse(args) do
      {parsed, args, _} ->
        IO.inspect {:parsed, parsed, :args, args}
    end
  end
end