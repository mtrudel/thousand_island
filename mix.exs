defmodule ThousandIsland.MixProject do
  use Mix.Project

  def project do
    [
      app: :thousand_island,
      version: "0.1.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
    [extra_applications: [:logger]]
  end

  defp deps() do
    [
      {:telemetry, "~> 0.4.1"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false}
    ]
  end
end
