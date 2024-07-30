defmodule KineticLib.CaseTransform do
  @moduledoc """
  Utility functions around case transformation, inspired by CozyCase, powered
  by Inflex.

  CozyCase is a fork of Inflex which has some minor regressions for some
  transformations and invalid type specifications, but provides better
  ergonomics for working with the case transformations.

  Only string or atom values or keys are transformed.

  The main ergonomic improvements of CozyCase are:

  - better conversion function names (`snake_case` instead of `underscore`;
    `camel_case` instead of `camelize/2`) and
  - transparent support for nested (map‡ or list of map) conversions.

  ‡ Most structs will be returned without modification. Those representing
  enumerable data structures (such as `Range` or `MapSet`) will be iterated
  over as if they were a list.

  ## Examples

  Strings or atoms are converted directly:

      iex> KineticLib.CaseTransform.snake_case("HelloWorld")
      "hello_world"

      iex> KineticLib.CaseTransform.snake_case(HelloWorld)
      "hello_world"

  Maps or lists of maps have their keys recursively converted:

      iex> KineticLib.CaseTransform.pascal_case(%{
      ...>  family_members: [
      ...>    %{name: "Lily", age: 50, hobbies: ["Dreaming", "Singing"]},
      ...>    %{"name" => "Charlie", "age" => 55, "hobbies" => ["Dreaming", "Singing"]}
      ...>  ]
      ...>})
      %{
        "FamilyMembers" => [
          %{"Name" => "Lily", "Age" => 50, "Hobbies" => ["Dreaming", "Singing"]},
          %{"Name" => "Charlie", "Age" => 55, "Hobbies" => ["Dreaming", "Singing"]}
        ]
      }
  """

  defmodule CamelCase do
    @moduledoc false
    def convert(term), do: Inflex.camelize(term, :lower)
  end

  defmodule KebabCase do
    @moduledoc false
    def convert(term), do: Inflex.parameterize(term)
  end

  defmodule PascalCase do
    @moduledoc false
    def convert(term), do: Inflex.camelize(term, :upper)
  end

  defmodule SnakeCase do
    @moduledoc false
    def convert(term), do: Inflex.underscore(term)
  end

  @type scalar_types :: String.t() | atom()
  @type nested_types :: map() | list()

  @doc """
  Converts multi-word terms to `snake_case` format.
  """
  def snake_case(term) when is_binary(term) or is_atom(term), do: convert_plain(term, SnakeCase)
  def snake_case(term) when is_map(term) or is_list(term), do: convert_nest(term, SnakeCase)

  @doc """
  Converts multi-word terms to `kebab-case` format.
  """
  def kebab_case(term) when is_binary(term) or is_atom(term), do: convert_plain(term, KebabCase)
  def kebab_case(term) when is_map(term) or is_list(term), do: convert_nest(term, KebabCase)

  @doc """
  Converts multi-word terms to `camelCase` format.
  """
  def camel_case(term) when is_binary(term) or is_atom(term), do: convert_plain(term, CamelCase)
  def camel_case(term) when is_map(term) or is_list(term), do: convert_nest(term, CamelCase)

  @doc """
  Converts multi-word terms to `PascalCase` format.
  """
  def pascal_case(term) when is_binary(term) or is_atom(term), do: convert_plain(term, PascalCase)
  def pascal_case(term) when is_map(term) or is_list(term), do: convert_nest(term, PascalCase)

  defp convert_plain(string, module) when is_binary(string), do: module.convert(string)

  defp convert_plain(atom, module) when is_atom(atom) do
    string =
      case Atom.to_string(atom) do
        "Elixir." <> rest -> rest
        string -> string
      end

    module.convert(string)
  end

  defp convert_plain(value, _module), do: value

  defp convert_nest(struct, module) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> convert_nest(module)
  end

  defp convert_nest(map, module) when is_map(map) do
    for {k, v} <- map, into: %{} do
      {convert_plain(k, module), convert_nest(v, module)}
    end
  rescue
    # input map is not Enumerable
    Protocol.UndefinedError -> map
  end

  defp convert_nest(list, module) when is_list(list),
    do: Enum.map(list, &convert_nest(&1, module))

  defp convert_nest(any, _module), do: any
end
