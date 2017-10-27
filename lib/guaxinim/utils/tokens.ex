defmodule Guaxinim.Utils.Tokens do
  alias Guaxinim.Database.FunctionCall
  alias Makeup.Formatters.HTML.HTMLFormatter
  require EEx

  alias Guaxinim.Utils.URL

  def split_into_lines(tokens) do
    {lines, last_line} =
      Enum.reduce tokens, {[], []}, (fn {ttype, meta, text} = tok, {lines, line} ->
        case String.split(text, "\n") do
          [_] -> {lines, [tok | line]}
          [part | parts] ->
            first_line = [{ttype, meta, part} | line] |> :lists.reverse

            all_but_last_line =
              parts
              |> Enum.slice(0..-2)
              |> Enum.map(fn tok_text -> [{ttype, meta, tok_text}] end)
              |> :lists.reverse

            last_line_text = Enum.at(parts, -1)
            last_line = [{ttype, meta, Enum.at(parts, -1)}]

            case last_line_text do
              "" -> {all_but_last_line ++ [first_line | lines], []}
              _ -> {all_but_last_line ++ [first_line | lines], last_line}
            end

        end
      end)

    [last_line | lines]
    |> :lists.reverse
    |> Enum.with_index(1)
  end

  defp escape(string) do
    escape_map = [{"&", "&amp;"}, {"<", "&lt;"}, {">", "&gt;"}, {~S("), "&quot;"}]
    Enum.reduce escape_map, string, fn {pattern, escape}, acc ->
      String.replace(acc, pattern, escape)
    end
  end

  EEx.function_from_string(:defp, :render_token, """
  <span\
  <%= if css_class do %> class="<%= css_class %>"<% end %>\
  <%= if meta[:group_id] do %> data-group-id="<%= meta[:group_id] %>"<% end %>\
  ><a class="guaxinim-source-link" href="<%= url %>"><%= escaped_value %></a></span>\
  """, [:escaped_value, :css_class, :meta, :url])

  def format_token_with_link({tag, meta, value}, url) do
    escaped_value = escape(value)
    css_class = Makeup.Token.Utils.css_class_for_token_type(tag)
    render_token(escaped_value, css_class, meta, url)
  end

  def format_token(config, file, {{:name, _, text} = token, line_nr}) do
    case FunctionCall.lookup_f_file_line!({text, file, line_nr}) do
      nil -> HTMLFormatter.format_token(token)

      %{m: m, f: f, a: a} ->
        case URL.url_for_mfa(config, file, {m, f, a}) do
          nil -> HTMLFormatter.format_token(token)
          url -> format_token_with_link(token, url)
        end
    end
  end
  def format_token(_, _, {token, _}), do: HTMLFormatter.format_token(token)

  defp line_to_html(config, file, {tokens, line_nr}) do
    tokens
    |> Enum.map(fn token -> format_token(config, file, {token, line_nr}) end)
    |> Enum.join("")
  end

  defp line_nr_anchor(line_nr, anchor_padding, true) do
    text =
      line_nr
      |> Integer.to_string
      |> String.pad_leading(anchor_padding)

    ~s(<a id="L#{line_nr}"></a><a class="lineno" href="#L#{line_nr}">#{text}</a>)
  end
  defp line_nr_anchor(line_nr, _, false) do
    ~s(<a class="lineno" id="L#{line_nr}"></a>)
  end

  def lines_to_html_data(config, file, anchor_padding, token_lines, line_numbers? \\ true) do
    code =
      token_lines
      |> Enum.map(fn line -> line_to_html(config, file, line) end)
      |> Enum.join("\n")

    {_, line_numbers} = Enum.unzip(token_lines)
    anchors =
      line_numbers
      |> Enum.map(fn line_nr ->
           line_nr_anchor(line_nr, anchor_padding, line_numbers?)
         end)
      |> Enum.join("\n")

    {anchors, code}
  end
end