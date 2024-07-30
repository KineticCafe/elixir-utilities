defmodule KineticLib.Data do
  @moduledoc """
  Utilities for manipulating data and data structures
  """

  @doc """
  Returns true if the value would be considered empty.

  | value type    | result                             |
  | ------------- | ---------------------------------- |
  | `nil`         | `true`                             |
  | binary        | `String.trim_leading(value) == ""` |
  | list          | `value == []`                      |
  | struct        | `false`                            |
  | map           | `map_size(value) == 0`             |
  | Enumerable    | `Enum.empty?(value)`               |
  | anything else | `false`                            |

  - `nil` is empty
  - non-struct maps are empty if `map_size/1` is `0`
  - lists are empty if they equal `[]`
  - strings are empty if, when trimmed of leading spaces, they are equal to an
    empty string (`""`)
  - values implementing the `Enumerable` protocol are empty if `Enum.empty?/1`
    returns `true`
  - all other values, including structs are empty
  """
  def empty?(nil), do: true
  def empty?(""), do: true
  def empty?([]), do: true
  def empty?(value) when is_binary(value), do: String.trim_leading(value) == ""
  def empty?(value) when is_list(value), do: false
  def empty?(value) when is_struct(value), do: false
  def empty?(value) when is_map(value), do: map_size(value) == 0

  def empty?(value) do
    if Enumerable.impl_for(value) do
      Enum.empty?(value)
    else
      false
    end
  end

  @doc """
  Returns true if the value would not be considered empty. See `empty?/1` for
  details.
  """
  def present?(value), do: !empty?(value)

  @doc """
  Like `Map.fetch/2`, but returns `{:error, reason}` on lookup failure.

  If the key is an atom or string, the error message is the same as reported
  with a KeyError (e.g., from `Map.fetch!/2`). If it is any other value, the
  message is "complex key not found". The map being searched is never included
  in the error message.

      iex> KineticLib.Data.map_fetch(%{a: 1}, :a)
      {:ok, 1}

      iex> KineticLib.Data.map_fetch(%{[:a, :b] => 1}, [:a, :b])
      {:ok, 1}

      iex> KineticLib.Data.map_fetch(%{a: 1}, :b)
      {:error, "key :b not found"}

      iex> KineticLib.Data.map_fetch(%{a: 1}, [:a, :b])
      {:error, "complex key not found"}
  """
  def map_fetch(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      :error ->
        if is_atom(key) or is_binary(key) do
          {:error, "key #{inspect(key)} not found"}
        else
          {:error, "complex key not found"}
        end

      {:ok, value} ->
        {:ok, value}
    end
  end

  @doc """
  Nil safe and struct safe alternative to `Map.get` and `get_in`.

  While traversing the nested keys, all values for the `keys` must be a map,
  struct, or nil, with the exception of the value for the last key.

  ## Examples

      iex> KineticLib.Data.dig(%{a: %{b: "bee"}}, [:a, :b])
      "bee"

      iex> KineticLib.Data.dig(%{a: %{c: %{}}}, [:a, :b])
      nil

      iex> KineticLib.Data.dig(%{a: %{c: %{}}}, ~w(a b)a)
      nil
  """
  def dig(nil, _keys), do: nil

  def dig(new, keys) when is_list(keys) do
    Enum.reduce_while(keys, new, fn key, acc ->
      acc
      |> Map.get(key)
      |> case do
        nil -> {:halt, nil}
        value -> {:cont, value}
      end
    end)
  end

  def dig(new, key), do: Map.get(new, key)

  @doc """
  Tries to get the value for a key from the `new` object if it exists and is not nil.
  If not, it will try to get it from the `old` object, or return nil.

  It is safe for either object to be `nil`, a Struct or a Map. And it can handle nesting
  like `get_in`, but unlike `get_in`, this function can be used for structs.

    ## Examples

      iex> KineticLib.Data.dig(%{a: %{b: "bee"}}, %{a: %{b: "bat"}}, [:a, :b])
      "bee"

      iex> KineticLib.Data.dig(%{a: nil}, %{a: %{b: "bat"}}, [:a, :b])
      "bat"

      iex> KineticLib.Data.dig(%{a: "apple"}, %{b: "bear"}, :b)
      "bear"
  """
  def dig(new, old, key) do
    case dig(new, key) do
      nil -> dig(old, key)
      value -> value
    end
  end

  @doc """
  Like dig/3 but with multiple fallbacks if `nil` is returned.

  Priority of operators:

  ```
  new.key1 > new.key2 > old.key1 > old.key2
  ```

  ## Examples

      iex> KineticLib.Data.dig(%{d: "dog"}, %{b: "bat"}, :c, :b)
      "bat"

      iex> KineticLib.Data.dig(%{a: %{d: "dog"}}, %{a: %{b: "bat"}}, [:a, :d], :a)
      "dog"
  """
  def dig(new, old, key1, key2) do
    with nil <- dig(new, key1),
         nil <- dig(new, key2),
         nil <- dig(old, key1) do
      dig(old, key2)
    end
  end

  @doc """
  Checks that `data1` is a subset of, or equal to `data2`. Works with maps and
  structs.

  ## Examples

      iex> KineticLib.Data.subset?(%{code: "A"}, %Kinetic.Resources.Product{code: "A", data: %{}})
      true

      iex> KineticLib.Data.subset?(%{code: "A", data: %{}}, %{code: "A"})
      false
  """
  def subset?(data1, data2) when is_map(data1) and is_map(data2) do
    match?(^data1, Map.take(data2, Map.keys(data1)))
  end
end
