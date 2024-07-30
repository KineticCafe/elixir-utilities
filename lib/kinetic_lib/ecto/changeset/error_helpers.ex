defmodule KineticLib.Ecto.Changeset.ErrorHelpers do
  @moduledoc "Common functions for handling changeset errors."

  alias Ecto.Changeset

  @doc """
  Merge changeset errors from the `source` changeset into the `target`
  changeset.

  If `target` is provided as an atom, `source` is treated as the changeset from
  a failed Multi operation, and `target` will be used as the key to the
  changeset `operations` so that the errors from `source` are merged into the
  changeset `source.operations[target]`.
  """
  def merge_changeset_errors(source, target) when is_atom(target) do
    merge_changeset_errors(source, source.operations[target])
  end

  def merge_changeset_errors(source, target) do
    Enum.reduce(source.errors, target, fn {field, {msg, additional}}, acc ->
      Changeset.add_error(acc, field, msg, additional)
    end)
  end

  @doc """
  Format the changeset errors into a keyword list suitable for use in a GraphQL
  response.
  """
  def format_changeset(changeset) do
    Enum.map(
      changeset.errors,
      &[message: "#{elem(&1, 0)} #{elem(elem(&1, 1), 0)}", details: elem(elem(&1, 1), 1)]
    )
  end

  def format_changeset_messages(changeset) do
    Enum.map(changeset.errors, fn {key, {message, _details}} -> "#{key}: #{message}" end)
  end

  @doc """
  Format the a result tuple, ignoring non-changeset results.
  """
  def format_changeset_result({:error, _op, %Changeset{} = changeset, _changes}) do
    {:error, format_changeset(changeset)}
  end

  def format_changeset_result({:error, %Changeset{} = changeset}) do
    {:error, format_changeset(changeset)}
  end

  def format_changeset_result(val) do
    val
  end
end
