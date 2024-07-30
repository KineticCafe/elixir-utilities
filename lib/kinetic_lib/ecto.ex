defmodule KineticLib.Ecto do
  @moduledoc """
  Provides Ecto related helper functions.
  """

  defdelegate schema_fields(schema, options \\ []),
    to: KineticLib.Ecto.Schema,
    as: :fields

  @upsert_all_opts_defaults [
    returning: false,
    replace_fields_except: [:insert_only]
  ]

  @doc """
  Performs an insert_all which replaces fields in an existing record on conflict.

  ## Options:
    * `:returning` - Whether struct should be returned. Defaults to
      `#{@upsert_all_opts_defaults[:returning]}`.

    * `:replace_fields_except` - Fields NOT to replace. See special values in
      `KineticLib.Ecto.Schema.fields/2`. Defaults to
      `#{inspect(@upsert_all_opts_defaults[:replace_fields_except])}`

    * `:conflict_target` - See `:conflict_target` in `Ecto.Repo` for options.
      If not given, it will check for a `conflict_target/0` function on the
      `schema_module`. If not present, an error will be thrown.
  """
  def upsert_all(repo, schema_module, entries, opts \\ []) do
    opts = Keyword.merge(@upsert_all_opts_defaults, opts)

    replace_fields =
      KineticLib.Ecto.schema_fields(schema_module, except: opts[:replace_fields_except])

    conflict_target =
      Keyword.get_lazy(opts, :conflict_target, fn ->
        if function_exported?(schema_module, :conflict_target, 0) do
          schema_module.conflict_target()
        else
          raise "Expected `:conflict_target` to be passed in `opts`, or `conflict_target/0` to be implemented in the schema module"
        end
      end)

    repo.insert_all(
      schema_module,
      entries,
      on_conflict: {:replace, replace_fields},
      conflict_target: conflict_target,
      returning: opts[:returning]
    )
  end
end
