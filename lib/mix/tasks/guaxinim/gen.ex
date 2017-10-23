
defmodule Mix.Tasks.Guaxinim.Gen do
  @moduledoc """
  Turns the following project into a literate program.
  """
  use Mix.Task

  def run(_args) do
    Guaxinim.run()
  end
end