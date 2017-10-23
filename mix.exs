defmodule Guaxinim.Mixfile do
  use Mix.Project

  def project do
    [
      app: :guaxinim,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      guaxinim: [
        sources: ["lib"],
        destination: "literate"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.16.3", only: :dev, runtime: false},
      {:amnesia, "~> 0.2.7"},
      {:makeup, "~> 0.2.0"},
      {:makeup_elixir, "~> 0.2.0"},
      {:earmark, "~> 1.2"},
      {:ex_spirit, "~> 0.3.3"},
      {:benchee, "~> 0.9", only: :dev},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end
end
