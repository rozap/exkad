defmodule Exkad.Cli do
  def main(args) do
    case OptionParser.parse(args) do
      {parsed, args, _} ->
        IO.inspect {:args, parsed, args}
    end
  end
end