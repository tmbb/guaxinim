defmodule GuaxinimTest do
  @moduledoc """
  A module created just to show guaxinim's linking capabilities
  """

  @doc """
  Link to a function defined in this project
  """
  def f1 do
    Guaxinim.run()
  end


  @doc """
  Links to functions from the Elixir standard library
  """
  def f2 do
    _ignore = File.ls!
    Path.join("etc", "var")
  end


  @doc """
  Link to a function from an external package
  """
  def f3 do
    # Function with arity = 1
    Makeup.ElixirLexer.lex("source")
    # Function with arity = 2
    Makeup.ElixirLexer.lex("source", [])
  end


  @doc """
  Link to a function from Erlang's standard library
  """
  def f4 do
    :dgp.ctp()
  end


  @doc """
  Link to a function from the same file.
  """
  def f5 do
    # You can also link to functions in the same file
    f1()
  end

end
