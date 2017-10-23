defmodule Guaxinim.Utils.Path do

  def strip_common_prefix_from_lists([x | xs], [x | ys]),
    do: strip_common_prefix_from_lists(xs, ys)
  def strip_common_prefix_from_lists([], ys),
    do: {[], ys}
  def strip_common_prefix_from_lists(xs, ys),
    do: {xs, ys}

  def path(from: src, to: dst) when src == dst, do: ""
  def path(from: src, to: dst) do
    src_parts = Path.split(src)
    dst_parts = Path.split(dst)
    {src_suffix, dst_suffix} = strip_common_prefix_from_lists(src_parts, dst_parts)
    case src_suffix do
      [_ | _] ->
        dots = List.duplicate("..", length(src_suffix) - 1)
        Path.join(dots ++ dst_suffix)
      [] ->
        Path.join(["./", dst_suffix])
    end
  end

end