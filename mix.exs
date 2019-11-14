defmodule ThousandIsland.MixProject do
  use Mix.Project

  def project do
    [
      app: :thousand_island,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end
end
