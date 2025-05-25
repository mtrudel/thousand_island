defmodule ThousandIsland.MixProject do
  use Mix.Project

  def project do
    [
      app: :thousand_island,
      version: "1.3.14",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      name: "Thousand Island",
      description: "A simple & modern pure Elixir socket server",
      source_url: "https://github.com/mtrudel/thousand_island",
      package: [
        maintainers: ["Mat Trudel"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/mtrudel/thousand_island"},
        files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"]
      ],
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger, :ssl]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_deps: :apps_direct,
      plt_add_apps: [:public_key],
      flags: [
        "-Werror_handling",
        "-Wextra_return",
        "-Wmissing_return",
        "-Wunknown",
        "-Wunmatched_returns",
        "-Wunderspecs"
      ]
    ]
  end

  defp docs do
    [
      main: "ThousandIsland",
      logo: "assets/ex_doc_logo.png",
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
