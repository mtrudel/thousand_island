defmodule ThousandIsland.MixProject do
  use Mix.Project

  def project do
    [
      app: :thousand_island,
      version: "0.6.1",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      name: "Thousand Island",
      description: "A simple & modern pure Elixir socket server",
      source_url: "https://github.com/mtrudel/thousand_island",
      package: [
        files: ["lib", "test", "mix.exs", "README*", "LICENSE*"],
        maintainers: ["Mat Trudel"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/mtrudel/thousand_island"}
      ],
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger, :ssl]]
  end

  defp deps() do
    [
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:machete, ">= 0.0.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.25", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [plt_core_path: "priv/plts", plt_file: {:no_warn, "priv/plts/dialyzer.plt"}]
  end

  defp docs do
    [
      main: "ThousandIsland",
      groups_for_modules: [
        Transport: [
          ThousandIsland.Transport,
          ThousandIsland.Transports.TCP,
          ThousandIsland.Transports.SSL
        ]
      ]
    ]
  end
end
