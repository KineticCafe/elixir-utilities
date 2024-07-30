defmodule KineticLib.Ecto.ErlangTerm do
  @moduledoc """
  A custom Ecto type to use with data in the "Erlang external term format". It
  is stored in the database as binary, and loaded from the database as an Erlang
  term.

  This implementation is based on code found in [idempotency_plug][1]
  (Copyright(c) 2023 Dan Schultzer & the Contributors, released under the MIT
  licence)

  [1]: https://github.com/danschultzer/idempotency_plug
  """

  use Ecto.Type

  @impl true
  def type, do: :binary

  @impl true
  def cast(term), do: {:ok, term}

  @impl true
  def load(bin) when is_binary(bin),
    do: {:ok, KineticLib.non_executable_binary_to_term(bin, [:safe])}

  @impl true
  def dump(term), do: {:ok, :erlang.term_to_binary(term)}
end
