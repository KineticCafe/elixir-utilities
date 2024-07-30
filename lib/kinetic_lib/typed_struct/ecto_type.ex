defmodule KineticLib.TypedStruct.EctoType do
  @moduledoc """
  A TypedStruct plugin that requires the addition of Ecto types in order to
  define a schemaless changeset map.
  """

  use TypedStruct.Plugin

  @impl true
  defmacro init(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :ts_fields_ecto_type, accumulate: true)
    end
  end

  @impl true
  def field(name, _type, opts, _env) do
    if ecto_type = opts[:ecto] do
      quote do
        @ts_fields_ecto_type {unquote(name), unquote(ecto_type)}
      end
    end
  end

  @impl true
  def after_definition(_opts) do
    quote do
      if !Enum.empty?(@ts_fields_ecto_type) do
        @ts_fields_ecto_type_schema Map.new(@ts_fields_ecto_type)
        @doc """
        The Ecto types for `#{__MODULE__}`.
        """
        def ecto_types(struct \\ %__MODULE__{}), do: {struct, @ts_fields_ecto_type_schema}

        Module.delete_attribute(__MODULE__, :ts_fields_ecto_type_schema)
      end

      Module.delete_attribute(__MODULE__, :ts_fields_ecto_type)
    end
  end
end
