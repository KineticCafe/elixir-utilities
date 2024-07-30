defmodule KineticLib.Ecto.Functions do
  @moduledoc """
  Macros that simulate SQL functions using Ecto fragments that are expanded in
  Ecto queries.

  These functions should work regardless of the SQL driver.
  """

  @doc """
  Joins two string values together using the `||` operator.
  """
  defmacro join_str(left, right, joiner \\ " ") do
    quote do
      fragment("? || ? || ?", unquote(left), unquote(joiner), unquote(right))
    end
  end

  @doc """
  Calls `round(avg(column), digits)`.
  """
  defmacro rounded_average(column, digits \\ 2) do
    quote do
      fragment("round(avg(?), ?)", unquote(column), ^unquote(digits))
    end
  end

  @doc """
  Calls `nullif(column, match)`.
  """
  defmacro nullif(column, match) do
    quote do
      fragment("nullif(?, ?)", unquote(column), ^unquote(match))
    end
  end
end
