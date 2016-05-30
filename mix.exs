defmodule Cvalda.Mixfile do
  use Mix.Project

  def project do
    [app: :cvalda,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     dialyzer: [plt_add_apps: [:inets, :redix, :connection]],
     deps: deps]
  end

  def application do
    [applications: [:logger, :redix, :amqp, :inets],
     mod: {Cvalda, []}]
  end

  defp deps do
    [
      {:redix, "~> 0.3.6"},
      {:amqp, "~> 0.1.4"},
      {:exrm, "~> 1.0.5", only: [:dev]},
      {:dialyxir, "~> 0.3", only: [:dev]}
    ]
  end
end
