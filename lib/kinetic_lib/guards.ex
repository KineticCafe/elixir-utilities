defmodule KineticLib.Guards do
  @moduledoc "Helpful guard statements"

  @doc """
  A guard for checking that the parameter is binary with at least 1 byte of
  data.
  """
  defguard is_non_empty_binary(value) when is_binary(value) and byte_size(value) > 0
end
