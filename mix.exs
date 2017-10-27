defmodule Guaxinim.Mixfile do
  use Mix.Project

  def project do
    [
      app: :guaxinim,
      version: "0.1.1",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      guaxinim: [
        src: "lib",
        dst: "literate",
        project_title: "Guaxinim"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def docs do
    [
      main: "Guaxinim",
      logo: "assets/logo/logo.png",
      extras: ["README.md"]
    ]
  end

  def package do
    [
      description: "Literate programming for Elixir with hyperlinked source-",
      files: ["lib", "priv", "mix.exs", "README.md"],
      maintainers: ["Tiago Barroso <tmbb@campus.ul.pt>"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/tmbb/guaxinim"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.18.1", only: :dev, runtime: false},
      {:amnesia, "~> 0.2.7"},
      {:makeup, "~> 0.3.0"},
      {:makeup_elixir, "~> 0.3.1"},
      {:earmark, "~> 1.2"},
      {:ex_spirit, "~> 0.3.3"},
      {:benchee, "~> 0.9", only: :dev},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end
end
