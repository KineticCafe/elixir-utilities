defmodule KineticLib.Ecto.Explain do
  @moduledoc """
  Enhances a Repo module with `explain_plan/2` and `explain_plan?/1` that can be placed in a query
  pipeline to log the `EXPLAIN` result before continuing on to execute the query.
  """

  require Logger

  @typedoc """
  Options to `KineticLib.Ecto.Explain.explain_plan/3` or `Repo.explain_plan/2` for
  generating an explain plan.

  - `name`: The name of the explain plan. Included in the logged output if
    present and may be used for filtering with `explain_plan?/1`.
  - `level`: A valid Logger level (`:debug`, `:info`, `:warning`, `:error`).
    Defaults to `:debug`.
  - `metadata`: Additional metadata to provide for the logging message.
    Defaults to `[]`.
  - `operation`: the operation to explain, defaults to `:all`, but should be
    `:update_all` or `:delete_all` if the repo operation will be an update or
    delete.
  - `options`: the options to pass to the builtin explain function, as
    documented in `Ecto.Adapters.SQL.explain/4`.
  """
  @type option ::
          {:name, String.t()}
          | {:level, Logger.level()}
          | {:metadata, Logger.metadata()}
          | {:operation, :all | :delete_all | :update_all}
          | {:options, Keyword.t()}
  @type options :: [option()]

  defmacro __using__(_) do
    quote do
      @doc """
      Explain the provided query with `Logger.log/3` to show the output of the database's
      `EXPLAIN`. Returns the incoming query so that the explain plan can be pipelined.
      """
      def explain_plan(query, options \\ []) do
        KineticLib.Ecto.Explain.explain_plan(query, __MODULE__, options)
      end

      @doc """
      Returns true if the named query can be explained.

      The default implementation always returns true.
      """
      def explain_plan?(_query_name) do
        true
      end

      defoverridable explain_plan?: 1
    end
  end

  @doc """
  Explain the provided query with `Logger.log/3` to show the output of the database's
  `EXPLAIN`. Returns the incoming query so that the explain plan can be pipelined.
  """
  def explain_plan(query, repo, options \\ []) do
    {name, options} = Keyword.pop(options, :name)
    level = Keyword.get(options, :level, :debug)

    should_explain? =
      cond do
        Logger.compare_levels(level, Logger.level()) == :lt -> false
        function_exported?(repo, :explain_plan?, 1) -> repo.explain_plan?(name)
        true -> true
      end

    if should_explain? do
      metadata = Keyword.get(options, :metadata, [])
      operation = Keyword.get(options, :operation, :all)
      explain_options = Keyword.get(options, :options, [])

      {sql, _vars} = repo.to_sql(operation, query)

      header =
        if name do
          "Explain query #{name} is "
        else
          "Explain query is "
        end

      Logger.log(
        level,
        [header, sql, ":\n", repo.explain(operation, query, explain_options)],
        metadata
      )

      query
    else
      query
    end
  end
end
