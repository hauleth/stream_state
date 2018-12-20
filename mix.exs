defmodule StreamState.MixProject do
  use Mix.Project

  def project do
    [
      app: :stream_state,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_options: [warnings_as_errors: true],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.json": :test,
        "coveralls.html": :test,
        docs: :docs,
        "inchci.add": :docs,
        "inch.report": :docs
      ],
      dialyzer: [plt_add_apps: [:ex_unit]]
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
      {:stream_data, "~> 0.4.2"},

      # Documentation
      {:ex_doc, ">= 0.0.0", only: [:docs]},
      {:inch_ex, "~> 1.0", only: [:docs]},

      # Testing
      {:excoveralls, "~> 0.10.3", only: [:test]},
      {:dialyxir, ">= 0.0.0", runtime: false, only: [:dev, :test]},
      {:junit_formatter, ">= 0.0.0", only: [:test]}
    ]
  end
end
