defmodule Guaxinim.Config do
  defstruct [
    src: nil,
    dst: nil,
    project_title: nil
  ]

  def from_mix() do
    guaxinim_user_config = Keyword.get(Mix.Project.config(), :guaxinim, [])
    src = Keyword.get(guaxinim_user_config, :src, "lib")
    dst = Keyword.get(guaxinim_user_config, :dst, "literate")
    project_title = Keyword.get(guaxinim_user_config, :project_title, "Add Title...")

    # Paths will be relative to the mix project's root
    %__MODULE__{
      src: Path.absname(src),
      dst: Path.absname(dst),
      project_title: project_title
    }
  end
end