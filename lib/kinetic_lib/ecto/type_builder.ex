if Code.loaded?(Ecto.Type) do
  defmodule KineticLib.Ecto.TypeBuilder do
    @moduledoc """
    This module makes it easier to define map-basd Ecto types as an alternative to
    embedded schemas, which have a number of sharp edges, using TypedStruct.

    It defines implementations for `type/0`, `cast/1`, `dump/1`, and `load/1`.

    It automatically defines `new/1` to create a new instance of the type using the
    required `changeset/2` implementation.
    """

    defmacro __using__(_) do
      quote do
        use Ecto.Type

        import KineticLib.Ecto.Type, only: [typedstruct: 1, typedstruct: 2]
        import Ecto.Changeset

        @behaviour KineticLib.Ecto.Type

        @doc """
        Create a new validated instance of #{__MODULE__}.
        """
        def new(attrs), do: KineticLib.Ecto.Type.__new(__MODULE__, attrs)

        @impl Ecto.Type
        def type, do: :map

        @impl Ecto.Type
        def cast(item), do: KineticLib.Ecto.Type.__cast(__MODULE__, item)

        @impl Ecto.Type
        def dump(item), do: KineticLib.Ecto.Type.__dump(__MODULE__, item)

        @impl Ecto.Type
        def load(item), do: KineticLib.Ecto.Type.__load(__MODULE__, item)
      end
    end

    require TypedStruct

    @doc """
    Every `KineticLib.Ecto.Type` must implement a changeset/2 callback that
    implements an Ecto schemaless changeset.
    """
    @callback changeset(struct, map) :: Ecto.Changeset.t()

    defmacro typedstruct(opts \\ [], do: block) do
      plugins = [
        {:plugin, [], [{:__aliases__, [], [:KineticLib, :TypedStruct, :EctoType]}]},
        {:plugin, [], [{:__aliases__, [], [:KineticLib, :TypedStruct, :Json]}]}
      ]

      block =
        case block do
          {:__block__, opts, lines} ->
            {:__block__, opts, [plugins | lines]}

          {_, _, _} ->
            {:__block__, [], [plugins, block]}
        end

      quote do
        require TypedStruct

        TypedStruct.typedstruct(unquote(opts), do: unquote(block))
      end
    end

    def __new(module, attrs) do
      case module.changeset(attrs) do
        %{valid?: true} = changeset -> {:ok, Ecto.Changeset.apply_changes(changeset)}
        %{errors: errors} -> {:error, errors}
      end
    end

    def __cast(module, %module{} = item), do: {:ok, item}
    def __cast(module, %mod{}), do: {:error, "invalid type #{mod} for #{module}"}
    def __cast(module, attrs) when is_map(attrs), do: __new(module, attrs)

    def __cast(module, string) when is_binary(string) do
      case Jason.decode(string) do
        {:ok, map} when is_map(map) ->
          __cast(module, map)

        {:ok, _} ->
          {:error, message: "must be a JSON object"}

        {:error, %Jason.DecodeError{} = error} ->
          {:error, message: Jason.DecodeError.message(error)}
      end
    end

    def __cast(module, _), do: {:error, message: "invalid type for #{module}"}

    def __dump(module, item) do
      case __cast(module, item) do
        {:ok, %^module{} = value} -> {:ok, value}
        {:ok, _} -> :error
        {:error, _} -> :error
      end
    end

    def __load(module, item) do
      case __cast(module, item) do
        {:ok, %^module{} = value} -> {:ok, value}
        {:ok, _} -> :error
        {:error, _} -> :error
      end
    end
  end
end
