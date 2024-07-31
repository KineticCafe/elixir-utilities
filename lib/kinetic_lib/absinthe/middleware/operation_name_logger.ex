if Code.loaded?(Absinthe.Middleware) do
  defmodule KineticLib.Absinthe.Middleware.OperationNameLogger do
    @moduledoc """
    Expose the GraphQL operation name in logs. Pulled from the Mirego [blog][1].

    [1]: https://craft.mirego.com/2022-10-06-expose-graphql-operation-in-logs-with-absinthe
    """

    @behaviour Absinthe.Middleware

    alias Absinthe.Blueprint.Document.Operation
    alias KineticLib.SentryHelpers

    def call(resolution, _opts) do
      operation_name =
        case Enum.find(resolution.path, &current_operation?/1) do
          %Operation{name: name} when not is_nil(name) -> name
          _ -> "#NULL"
        end

      Logger.metadata(graphql_operation_name: operation_name)
      SentryHelpers.set_tags_context(%{graphql_operation_name: operation_name})

      resolution
    end

    defp current_operation?(%Operation{current: true}), do: true
    defp current_operation?(_), do: false
  end
end
