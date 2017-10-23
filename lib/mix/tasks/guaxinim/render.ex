defmodule Mix.Tasks.Guaxinim.Render do
  @moduledoc """
  Renders the current project into a literate program.
  """
  # This is all rather hacky.
  # I don't know where the Mnesia database is being created.
  # I'll have to find out if I ever want to implement some kind of caching.
  use Mix.Task
  # This task is extremely wasteful, generating and destroying
  # the database each time it is run.
  # We must destroy the database so that we don't make mistakes due
  # to a rare corner case in which a function named `f` (for example)
  # is removed and a variable named `f` is placed in the same line.
  # This makes the program create a link to a function when in fact
  # it's only a variable.
  # This corner case is probably very rare, but it's insidious.
  #
  # Currently, we only output the hyperlinked source, but in the future
  # we might have dependency graphs or other visualization tools,
  # and for those cases we can't afford to have stale values in the tables.
  #
  # The obvious optimization is to be intelligent while updating the database.
  def run(_args) do
    Amnesia.start()
    # Try to create a schema
    case Amnesia.Schema.create() do
      :ok -> IO.puts("Created schema.")
      _ -> IO.puts("Schema already exists.")
    end
    # Destroy the old version of the database, if it exists.
    Guaxinim.Database.destroy()
    # Create the database
    case Guaxinim.Database.create() do
      :ok -> IO.puts("Created database.")
      _ -> IO.puts("Database already exists.")
    end
    # Render the project
    Guaxinim.run()
    IO.puts("Project rendered.")
  end
end
