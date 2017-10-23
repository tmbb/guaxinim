defmodule Guaxinim.Internal.SourceFormatter do
  alias Guaxinim.Utils.Tokens
  require EEx

  @external_resource "lib/guaxinim/templates/code/elixir/code.html.eex"
  @external_resource "lib/guaxinim/templates/code/elixir/doc.html.eex"
  @external_resource "lib/guaxinim/templates/code/elixir/moduledoc.html.eex"
  @external_resource "lib/guaxinim/templates/code/elixir/typedoc.html.eex"
  @external_resource "lib/guaxinim/templates/code/elixir/comment.html.eex"

  EEx.function_from_file(:defp, :code_to_html,
    "lib/guaxinim/templates/code/elixir/code.html.eex",
    [:anchors, :code])

  EEx.function_from_file(:defp, :doc_to_html,
    "lib/guaxinim/templates/code/elixir/doc.html.eex",
    [:indent, :content, :function, :connector])

  EEx.function_from_file(:defp, :moduledoc_to_html,
    "lib/guaxinim/templates/code/elixir/moduledoc.html.eex",
    [:indent, :content, :module, :connector])

  EEx.function_from_file(:defp, :typedoc_to_html,
    "lib/guaxinim/templates/code/elixir/typedoc.html.eex",
    [:indent, :content, :type, :connector])

  EEx.function_from_file(:defp, :comment_to_html,
    "lib/guaxinim/templates/code/elixir/comment.html.eex",
    [:indent, :content])

  def block_to_html(config, file, anchor_padding, {:code, lines}) do
    {anchors, code} = Tokens.lines_to_html_data(config, file, anchor_padding, lines)
    code_to_html(anchors, code)
  end

  def block_to_html(_, _, anchor_padding, {:moduledoc, text, indent}) do
    html = Earmark.as_html!(text)
    moduledoc_to_html(indent + anchor_padding, html, nil, nil)
  end

  def block_to_html(_, _, anchor_padding, {:doc, text, indent}) do
    html = Earmark.as_html!(text)
    doc_to_html(indent + anchor_padding, html, nil, nil)
  end

  def block_to_html(_, _, anchor_padding, {:typedoc, text, indent}) do
    html = Earmark.as_html!(text)
    typedoc_to_html(indent + anchor_padding, html, nil, nil)
  end

  def block_to_html(_, _, anchor_padding, {:comment, text, indent}) do
    html = Earmark.as_html!(text)
    comment_to_html(indent + anchor_padding, html)
  end

  def blocks_to_html(config, %{file: file, blocks: blocks, anchor_padding: anchor_padding}) do
    blocks
    |> Enum.map(fn block -> block_to_html(config, file, anchor_padding, block) end)
    |> Enum.join("\n")
  end

end