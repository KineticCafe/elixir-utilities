defmodule KineticLib.EctoTestHelpers do
  @moduledoc """
  Helper functions for Ecto cases.
  """

  @doc """
  Transform a changeset's errors to be a map of field keys with an array of messages.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
