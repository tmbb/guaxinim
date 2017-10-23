defmodule Guaxinim.Internal.SourceParser do
  use ExSpirit.Parser, text: true

  defrule newline(
    alt([
      char(?\n),
      eoi()
    ])
  )

  defrule any_line(
    lexeme(
      seq([
        chars(-?\n, 0),
        newline()]))
  )

  defrule comment_line(
    lexeme(
      seq([
        chars(?\s, 0),
        char(?#),
        chars(-?\n, 0),
        newline()
      ]))
  )
  
  defrule doc_block_start(
    seq([
      chars(?\s, 0),
      lit("@doc"),
      chars(?\s, 1),
      alt([
        lit("\"\"\""),
        lit("~S\"\"\""),
        lit("~s\"\"\"")
      ]),
      chars(?\s, 0),
      newline(),
    ])
  )

  defrule moduledoc_block_start(
    seq([
      chars(?\s, 0),
      lit("@moduledoc"),
      chars(?\s, 1),
      alt([
        lit("\"\"\""),
        lit("~S\"\"\""),
        lit("~s\"\"\"")
      ]),
      chars(?\s, 0),
      newline(),
    ])
  )

  defrule heredoc_end(
    seq([
      chars(?\s, 0),
      lit("\"\"\""),
      chars(?\s, 0),
      newline()
    ])
  )

  defrule doc_block(
    seq([
      ignore(doc_block_start()),
      tag(:doc,
        repeat(
          lookahead_not(heredoc_end()) |> any_line(), 0)),
      ignore(heredoc_end())
    ])
  )

  defrule moduledoc_block(
    seq([
      ignore(moduledoc_block_start()),
      tag(:moduledoc,
        repeat(
          lookahead_not(heredoc_end()) |> any_line(), 0)),
      ignore(heredoc_end())
    ])
  )

  defrule comment_block(
    tag(:comment,
      repeat(comment_line(), 1))
  )

  defrule non_code_line(
    alt([
      comment_line(),
      doc_block_start(),
      moduledoc_block_start(),
      eoi(),
    ])
  )

  defrule code_line(
    seq([
      ignore(lookahead_not(non_code_line())),
      any_line()])
  )

  defrule code_block(
    tag(:code,
      repeat(lookahead_not(non_code_line()) |> any_line, 1))
  )

  defrule block(
    alt([
      code_block,
      comment_block,
      doc_block,
      moduledoc_block
    ])
  )

  defrule blocks(
    repeat(block)
  )

  def from_string(source) do
    parse(source, blocks)
  end

end