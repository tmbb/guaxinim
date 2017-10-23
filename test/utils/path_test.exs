defmodule Guaxinim.Utils.PathTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Guaxinim.Utils.Path, as: PathUtils

  property "definition of the function" do
    check all prefix <- list_of(binary()),
              [x | _] = xs_suffix <- list_of(binary(), min_length: 1),
              [y | _] = ys_suffix <- list_of(binary(), min_length: 1),
              x != y do
      xs = prefix ++ xs_suffix
      ys = prefix ++ ys_suffix
      assert {^xs_suffix, ^ys_suffix} = PathUtils.strip_common_prefix_from_lists(xs, ys)
    end
  end

  property "lists end with the suffixes" do
    check all xs <- list_of(binary()),
              ys <- list_of(binary()) do
      
      {xs_suffix, ys_suffix} = PathUtils.strip_common_prefix_from_lists(xs, ys)
      
      assert ^xs_suffix = Enum.slice(xs, -(length xs_suffix)..-1)
      assert ^ys_suffix = Enum.slice(ys, -(length ys_suffix)..-1)
    end
  end

end