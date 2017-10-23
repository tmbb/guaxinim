defmodule Guaxinim.Internal.SourceProcessor do
  alias Makeup.Lexers.ElixirLexer
  alias Guaxinim.Utils.Tokens
  alias Guaxinim.Internal.SourceParser

  defp indentation([line | _]) do
    # Evaluate the indentation level of the line.
    # Will only be used for comment blocks or for heredocs.
    # We will never need to know the indentation level of a code block.
    #
    # After having used ExSpirit to parse the file it might seem
    # a little clunky to use the `Regex` module.
    # The reason for this is that handling indentation in ExSpirit, although
    # completely doable is somewhat complex, and would require us
    # to define much stricter rules for what counts as a comment block.
    #
    # Parsing indentation in a post-processing step is the righ choice here.
    [{0, indent} | _] = Regex.run(~r/^(\s*)/, line, return: :index)
    indent
  end

  defp strip_hash(line) do
    # Strip the indentation and hash sign (`#`) from the line.
    # If the hash is followed by at least a space (`?\s`), strip the space too.
    [_, _, _, comment] = Regex.run(~r/(\s*)#(\s?)(.*)/, line)
    comment
  end

  defp strip_indent(line, indent) do
    # Strip a given level of indent.
    String.trim_leading(line, String.duplicate(" ", indent))
  end

  defp merge_blocks_and_token_lines(blocks, token_lines) do
    # We'll transform the blocks, consuming lines as we go.
    {result, _} = Enum.reduce blocks, {[], token_lines}, (fn
      # **Code blocks**: these blocks work with tokens and not raw lines of text.
      # They have no use for indentation, because they'll be rendered inside `<pre>` tags.
      {:code, lines}, {result, tok_lines} ->
        # Consume the appropriate number of lines:
        {block_token_lines, rest_token_lines} = Enum.split(tok_lines, length(lines))
        # The blocks are added to the front of the list.
        # They must be reversed [afterwards](#merge_blocks_and_token_lines.reverse)!
        {[{:code, block_token_lines} | result], rest_token_lines}

      # **Heredoce**: Guaxinim recognized 3 kinds of heredocs: `:moduledoc`, `:doc` and `:typedoc`.
      # They will be rendered side by side with the source, indented according to the
      # indentation in the original source file.
      # They will be tagged with the raw text and the indentation level.
      # The text will later be interpreted as Markdown and renderd into HTML
      {tag, lines} = block, {result, tok_lines} when tag in [:moduledoc, :doc, :typedoc] ->
        {_, rest_token_lines} = Enum.split(tok_lines, length(lines) + 2)
        indent = indentation(lines)
        {[{tag, to_text(indent, block), indent} | result], rest_token_lines}

      # **Comments**: comments are similar to the heredocs above.
      # They will be treated as Markdown and rendered into HTML.
      # They will be indented too.
      {:comment, lines} = block, {result, tok_lines} ->
        {_, rest_token_lines} = Enum.split(tok_lines, length(lines))
        indent = indentation(lines)
        {[{:comment, to_text(indent, block), indent} | result], rest_token_lines}
    end)

    # <a id="merge_blocks_and_token_lines.reverse"></a>
    # Reverse the order of the blocks
    :lists.reverse(result)
  end

    # Extract raw text from comment block:
  defp to_text(_, {:comment, lines}) do
    result = lines |> Enum.map(&strip_hash/1) |> Enum.join("\n")
    result
  end

  # Extract raw text from heredocs (`:doc`, `:moduledoc` and `:typedoc`)
  defp to_text(indent, {tag, lines}) when tag in [:doc, :moduledoc, :typedoc] do
    lines |> Enum.map(&strip_indent(&1, indent)) |> Enum.join("")
  end

  # Extract raw text from code block (implemented for completeness, it's not needed right now):
  defp to_text(_, {:code, lines}), do:
    Enum.join(lines, "")

  # Process the raw source of the file into blocks.
  def process_source(file, source) do
    tokens = ElixirLexer.lex(source, true)
    token_lines = Tokens.split_into_lines(tokens)
    %{error: nil, result: blocks} = SourceParser.from_string(source)
    merged_blocks = merge_blocks_and_token_lines(blocks, token_lines)
    anchor_padding =
      token_lines
      |> length
      |> Integer.to_string
      |> String.length

    %{file: file,
      blocks: merged_blocks,
      anchor_padding: anchor_padding}
  end

end