if Code.loaded?(Absinthe.Middleware) do
  defmodule KineticLib.Absinthe.Middleware.ChangesetErrors do
    @moduledoc """
    Absinthe Middleware to convert changeset errors into a somewhat more useful Absinthe
    error response.
    """

    @behaviour Absinthe.Middleware

    def call(%{errors: [_ | _] = errors} = resolution, _) do
      %{resolution | errors: Enum.map(errors, &transform_errors(&1, resolution))}
    end

    def call(resolution, _), do: resolution

    defp transform_errors(%Ecto.Changeset{} = changeset, resolution) do
      [
        message: "Error in mutation #{resolution.definition.name}",
        details:
          changeset
          |> Ecto.Changeset.traverse_errors(&format_error/1)
          |> Enum.map(fn {key, value} -> %{key: key, message: value} end)
      ]
    end

    defp transform_errors(error, _), do: error

    defp format_error({msg, opts}) do
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end
  end
end
