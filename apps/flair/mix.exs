defmodule Flair.MixProject do
  use Mix.Project

  def project do
    [
      app: :flair,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Flair.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:flow, "~> 0.14"},
      {:gen_stage, "~> 0.14"},
      {:kafka_ex, "~> 0.9"},
      {:jason, "~> 1.1"},
      {:statistics, "~> 0.6"},
      {:scos_ex, "~> 0.1", organization: "smartcolumbus_os"}
    ]
  end
end
