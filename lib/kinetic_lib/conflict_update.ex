defmodule KineticLib.ConflictUpdate do
  @moduledoc """
  A function to create an update query for an `on_conflict:` clause in
  `insert_all`.
  """

  @doc "A function to create an update query for a schema."
  defmacro conflict_update(schema, pattern) do
    e_schema = Macro.expand_once(schema, __CALLER__)
    e_pattern = Macro.expand_once(pattern, __CALLER__)

    update_args =
      e_schema
      |> columns(e_pattern)
      |> Enum.map(&{&1, {:fragment, [], ["EXCLUDED.#{&1}"]}})
      |> Keyword.new()

    {:update, [context: Elixir, import: Ecto.Query],
     [
       schema,
       [
         set: update_args
       ]
     ]}
  end

  defp columns(schema, :replace_all), do: schema.__schema__(:fields)

  defp columns(schema, :replace_all_except_primary_key),
    do: schema.__schema__(:fields) -- schema.__schema__(:primary_key)

  defp columns(_schema, {:replace, fields}), do: fields
end
