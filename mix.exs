defmodule ThousandIsland.MixProject do
  use Mix.Project

  def project do
    [
      app: :thousand_island,
      version: "0.4.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_path(Mix.env()),
      dialyzer: dialyzer(),
      name: "Thousand Island",
      description: "A simple & modern pure Elixir socket server",
      source_url: "https://github.com/mtrudel/thousand_island",
      package: [
        files: ["lib", "test", "mix.exs", "README*", "LICENSE*"],
        maintainers: ["Mat Trudel"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/mtrudel/thousand_island"}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :ssl]]
  end

  defp deps() do
    [
      {:telemetry, "~> 0.4.1"},
      {:ex_doc, "~> 0.21", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp elixirc_path(:test), do: ["lib/", "test/support"]
  defp elixirc_path(_), do: ["lib/"]

  defp dialyzer do
    [plt_core_path: "priv/plts", plt_file: {:no_warn, "priv/plts/dialyzer.plt"}]
  end
end
