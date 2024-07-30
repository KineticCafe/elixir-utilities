defmodule KineticLib.Ecto.Schema do
  @moduledoc """
  Provides a helper function for getting a list of fields from a schema,
  suitable for use in an insertion conflict `{:replace, fields}` clause.
  """

  defmacro __using__(_opts) do
    quote do
      alias KineticLib.Ecto.Schema

      @doc """
      Returns the list of fields for the schema, `:except` for the fields
      specified. See `KineticLib.Ecto.Schema.fields/2`.
      """
      def __fields__(options \\ []), do: Schema.fields(__MODULE__, options)

      @doc """
      Returns a `{:replace, fields}` tuple suitable for use in an insertion
      conflict clause. See `KineticLib.Ecto.Schema.replace/2`.
      """
      def __replace__(options \\ []), do: Schema.replace(__MODULE__, options)
    end
  end

  @doc """
  Returns the list of fields for the `schema`, `:except` certain fields
  provided in `options`.

  There are two special values that can show up in the `except` list:

  - `:primary_key` (removes the schema's primary key)
  - `:insert_only` (removes the schema's primary key and `inserted_at`).
  """
  def fields(schema, options \\ [])

  def fields(schema, []), do: schema.__schema__(:fields)

  def fields(schema, options) do
    except =
      options
      |> Keyword.take([:except])
      |> Keyword.values()
      |> List.flatten()
      |> Enum.flat_map(fn
        :primary_key -> schema.__schema__(:primary_key)
        :insert_only -> [:inserted_at | schema.__schema__(:primary_key)]
        value -> [value]
      end)

    schema.__schema__(:fields) -- except
  end

  @doc """
  Returns a `{:replace, fields}` tuple suitable for use in an insertion
  conflict clause. See `KineticLib.Ecto.Schema.fields/2`.
  """
  def replace(schema, options \\ []), do: {:replace, fields(schema, options)}
end
