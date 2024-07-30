defmodule KineticLib.Ecto.Functions.Postgres do
  @moduledoc """
  Macros that simulate PostgreSQL functions using Ecto fragments that are
  expanded in Ecto queries.

  These functions likely only work with PostgreSQL drivers and *may* require
  that specific extensions and table configurations be enabled.

  ### Extensions

  - [pgtrgm](https://www.postgresql.org/docs/current/pgtrgm.html)
  """

  @doc """
  Performs a similarity comparison using the `%` operator returning a boolean
  value.

  > `left_text % right_text → boolean`
  >
  > Returns `true` if its arguments have a similarity that is greater than the
  > current similarity threshold set by `pg_trgm.similarity_threshold`.

  Provided by the pgtrgm extension.
  """
  defmacro similar_to(left_text, right_text) do
    quote do
      fragment("? % ?", unquote(left_text), unquote(right_text))
    end
  end

  @doc """
  Returns a real number representing the similarity of the two arguments.

  > similarity (text, text) → real
  >
  > Returns a number that indicates how similar the two arguments are. The
  > range of the result is zero (indicating that the two strings are completely
  > dissimilar) to one (indicating that the two strings are identical).

  Provided by the pgtrgm extension.
  """
  defmacro similarity(left_text, right_text) do
    quote do
      fragment("similarity(?, ?)", unquote(left_text), unquote(right_text))
    end
  end

  @doc """
  Returns a real number representing the partial word similarity of the two
  arguments.

  > word_similarity (text, text) → real
  >
  > Returns a number that indicates the greatest similarity between the set of
  > trigrams in the first string and any continuous extent of an ordered set of
  > trigrams in the second string. For details, see the explanation below.

  Provided by the pgtrgm extension.
  """
  defmacro word_similarity(left_text, right_text) do
    quote do
      fragment("word_similarity(?, ?)", unquote(left_text), unquote(right_text))
    end
  end

  @doc """
  Returns a real number representing the whole word similarity of the two
  arguments.

  > strict_word_similarity (text, text) → real
  >
  > Same as `word_similarity`, but forces extent boundaries to match word
  > boundaries. Since we don't have cross-word trigrams, this function actually
  > returns greatest similarity between first string and any continuous extent
  > of words of the second string.

  Provided by the pgtrgm extension.
  """
  defmacro strict_word_similarity(left_text, right_text) do
    quote do
      fragment("strict_word_similarity(?, ?)", unquote(left_text), unquote(right_text))
    end
  end

  @doc """
  Subtracts `seconds` from `now() AT TIME ZONE 'UTC'`.
  """
  defmacro now_minus_seconds(seconds) do
    quote do
      fragment("now() AT TIME ZONE 'UTC' - INTERVAL '1 SECOND' * ?", unquote(seconds))
    end
  end

  @doc """
  Calls the `encode_relay_id(source_id, node_type)` function in the query.
  """
  defmacro as_relay_id(node_type, source_id) do
    quote do
      fragment(
        "encode_relay_id(?, ?)",
        unquote(source_id),
        ^unquote(node_type)
      )
    end
  end

  @doc """
  Calls the PostgreSQL function `regexp_replace(column, pattern, replace,
  options)`.
  """
  defmacro regexp_replace(column, pattern, replace, options \\ "") do
    quote do
      fragment(
        "regexp_replace(?, ?, ?, ?)",
        unquote(column),
        ^unquote(pattern),
        ^unquote(replace),
        ^unquote(options)
      )
    end
  end
end
