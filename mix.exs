defmodule KineticLib.MixProject do
  use Mix.Project

  @app_name :kinetic_lib

  def project do
    [
      app: @app_name,
      version: "0.0.1",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(env) when env in [:dev, :test], do: ["lib", "tasks", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:datix, "~> 0.3.2"},
      {:ecto, "~> 3.11.2"},
      {:ecto_sql, "~> 3.11.3"},
      {:ex_aws_s3, "~> 2.5.3"},
      {:git_cli, "~> 0.3.0", runtime: false},
      {:inflex, "~> 2.1.0"},
      {:jason, "~> 1.4.3"},
      {:observer_cli, "~> 1.7.4"},
      {:plug_crypto, "~> 2.1.0"},
      {:postgrex, "~> 0.18.0"},
      # Sentry is started in the kinetic app's application.ex
      {:sentry, "~> 10.6.2", runtime: false},
      {:tesla, "~> 1.11.2"},
      {:timex, "~> 3.7.11"},
      {:typedstruct, "~> 0.5.3"},
      {:zoneinfo, "~> 0.1.8"},
      {:credo, "~> 1.7.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.3", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34.2", only: :dev, runtime: false},
      {:sobelow, "~> 0.13.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      formatters: ["html"],
      before_closing_body_tag: fn
        :html ->
          """
          <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
          <script>mermaid.initialize({startOnLoad: true})</script>
          """

        _ ->
          ""
      end,
      extras: Path.wildcard("*.md")
    ]
  end
end
