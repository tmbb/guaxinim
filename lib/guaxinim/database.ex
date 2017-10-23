# ## General Description
#
# The Elixir AST discards column numbers, so we'll have to work
# with the line numbers alone
# The main problem with this limitation is that we can't distinguish
# two different function calls in the same line.
# We assume those cases will be rare and will make no attempt to fix this
# in the short term.
use Amnesia

# ## The Database
defdatabase Guaxinim.Database do
  # ### Function definitions
  deftable FunctionDefinition, [
      # Index, denormalized `{module, function, arity}`
      :mfa,
      # Normalized module, function and arity
      :m, :f, :a,
      # Is the function internal to the project?
      :internal?,
      # If it is external, which package does it come from?
      :package,
      # file and line of the first head of the definition
      :file, :line,
      # Keyword used to define the function (`:def`, `defp`, `defmacro`, etc.)
      :keyword,
      # Extra data we might decide to include
      :meta],
    type: :ordered_set do
  end

  # ### Function Calls
  deftable FunctionCall, [
      # Denormalized `{function, file, line}` tuple for faster queries
      :f_file_line,
      :m, :f, :a,
      # Function/macro from which the function is called
      :caller_mfa,
      # Module from which the function is called
      :caller_module,
      # File and line. Note that we don't have access to the column.
      :file, :line],
    type: :ordered_set do

    @doc """
    Lookup a function call by primary key.
    """
    def lookup_f_file_line!({f, file, line}) do
      read!({f, file, line})
    end
  end

  # ### Module Definitions
  #
  # Still no use for this
  deftable ModuleDefinition, [
    :m, :file, :line,
    :internal?, :package], type: :ordered_set do
  end

  # ### Module References (= aliases)
  #
  # Still no use for this
  deftable ModuleReference, [:m, :line], type: :ordered_set do
  end
end