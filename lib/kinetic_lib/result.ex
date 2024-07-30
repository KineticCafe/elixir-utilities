defmodule KineticLib.Result do
  @moduledoc ~S"""
  Functions to help with result typing (`{:ok, value} | {:error, reason}`),
  loosely modeled after Rust's [std::result][1].

  These functions are *not* intended to replace explicit tuple specification or
  pattern matching:

  ```elixir
  # INCORRECT
  KineticLib.Result.ok(42)

  # CORRECT
  {:ok, 42}
  ```

  In certain circumstances, these will be more readable:

  ```elixir
  # OK, but hard to read
  {:ok, dir |> Path.join(file) |> File.read!()}
  {:error, some |> long() |> transformation()}

  # Easier to read:
  dir
  |> Path.join(file)
  |> File.read!()
  |> KineticLib.Result.ok()

  some
  |> long()
  |> transformation()
  |> KineticLib.Result.error()
  ```

  Pipelined functions which return an unwrapped `value`, `:error`, or `nil`
  (where `nil` is considered an error) but are wanted as an ok/error tuple
  should use `new/2`.

  ```elixir
  something
  |> that_might_return_nil()
  |> KineticLib.Result.new()

  # returns {:ok, value} on success and {:error, "not found"} on nil or :error.
  # If a previous step returns a result tuple, that is passed through
  # unchanged.

  something
  |> that_might_return_nil()
  |> KineticLib.Result.new(reason: "access denied")

  # returns {:ok, value} on success and {:error, "access denied"} on nil or :error.
  # If a previous step returns a result tuple, that is passed through
  # unchanged.
  ```

  [1]: https://doc.rust-lang.org/std/result/
  """

  @type t(t, e) :: {:ok, t} | {:error, e}
  @type t(t) :: t(t, any())
  @type t :: t(term())

  @doc ~S"""
  Returns `true` if this is an `:ok` tuple.

  This may be used as a function guard.

  ### Examples

      iex> KineticLib.Result.is_ok({:ok, 42})
      true

      iex> KineticLib.Result.is_ok({:ok, 42, 43})
      true

      iex> KineticLib.Result.is_ok(:ok)
      false

      iex> KineticLib.Result.is_ok({:ok})
      false

      iex> KineticLib.Result.is_ok({:error, 42})
      false

      iex> KineticLib.Result.is_ok(:error)
      false
  """
  defguard is_ok(value) when is_tuple(value) and tuple_size(value) > 1 and elem(value, 0) == :ok

  @doc ~S"""
  Returns `true` if this is an `:error` tuple.

  This may be used as a function guard.

  ### Examples

      iex> KineticLib.Result.is_error({:error, 42})
      true

      iex> KineticLib.Result.is_error({:error, 42, 43})
      true

      iex> KineticLib.Result.is_error(:error)
      false

      iex> KineticLib.Result.is_error({:error})
      false

      iex> KineticLib.Result.is_error({:ok, 42})
      false

      iex> KineticLib.Result.is_error(:ok)
      false

      iex> KineticLib.Result.is_error({:ok})
      false
  """
  defguard is_error(value)
           when is_tuple(value) and tuple_size(value) > 1 and elem(value, 0) == :error

  @doc ~S"""
  Returns `true` if this is either an `:ok` tuple or an `:error` tuple.

  This may be used as a function guard.

  ### Examples

      iex> KineticLib.Result.is_result({:ok, 42})
      true

      iex> KineticLib.Result.is_result({:error, 42})
      true

      iex> KineticLib.Result.is_result({:ok, 42, 43})
      true

      iex> KineticLib.Result.is_result({:error, 42, 43})
      true

      iex> KineticLib.Result.is_result(:ok)
      false

      iex> KineticLib.Result.is_result(:error)
      false

      iex> KineticLib.Result.is_result({:ok})
      false

      iex> KineticLib.Result.is_result({:error})
      false
  """
  defguard is_result(value)
           when is_tuple(value) and tuple_size(value) > 1 and elem(value, 0) in [:ok, :error]

  @doc ~S"""
  Wrap the provided `value` as `{:ok, value}`, unless `value` is *already* an
  `:ok` or `:error` tuple.

  Single-element tuples are treated as values, even if the single element is
  `{:ok}` or `{:error}`.

  ### Examples

      iex> KineticLib.Result.ok(42)
      {:ok, 42}

      iex> KineticLib.Result.ok(nil)
      {:ok, nil}

      iex> KineticLib.Result.ok(:ok)
      {:ok, :ok}

      iex> KineticLib.Result.ok(:error)
      {:ok, :error}

      iex> KineticLib.Result.ok({:ok, 42})
      {:ok, 42}

      iex> KineticLib.Result.ok({:ok, 42, 43})
      {:ok, 42, 43}

      iex> KineticLib.Result.ok({:error, 41})
      {:error, 41}

      iex> KineticLib.Result.ok({:ok})
      {:ok, {:ok}}

      iex> KineticLib.Result.ok({:error})
      {:ok, {:error}}
  """
  def ok(value) when is_result(value), do: value
  def ok(value), do: {:ok, value}

  @doc ~S"""
  Wrap the provided `value` as `{:error, value}`, unless `value` is *already*
  an `:ok` or `:error` tuple.

  Single-element tuples are treated as values, even if the single element is
  `{:ok}` or `{:error}`.

  ### Examples

      iex> KineticLib.Result.error(42)
      {:error, 42}

      iex> KineticLib.Result.error(nil)
      {:error, nil}

      iex> KineticLib.Result.error(:error)
      {:error, :error}

      iex> KineticLib.Result.error(:ok)
      {:error, :ok}

      iex> KineticLib.Result.error({:error, 42})
      {:error, 42}

      iex> KineticLib.Result.error({:error, 42, 43})
      {:error, 42, 43}

      iex> KineticLib.Result.error({:ok, 41})
      {:ok, 41}

      iex> KineticLib.Result.error({:error})
      {:error, {:error}}

      iex> KineticLib.Result.error({:ok})
      {:error, {:ok}}
  """
  def error(value) when is_result(value), do: value
  def error(value), do: {:error, value}

  @doc ~S"""
  Returns the `value` stored in an `{:ok, value}` tuple, or returns the
  `default` value.

  Tuples with more than one value element (`{:ok, value1, value2}`) will be
  unwrapped to value tuples (`{value1, value2}`). Single-element tuples
  (`{:ok}`) are treated regular values (resulting in the default return).

  ### Examples

      iex> KineticLib.Result.unwrap({:ok, 42})
      42

      iex> KineticLib.Result.unwrap({:ok, nil})
      nil

      iex> KineticLib.Result.unwrap({:ok, {42, 43}})
      {42, 43}

      iex> KineticLib.Result.unwrap({:ok, 42, 43})
      {42, 43}

      iex> KineticLib.Result.unwrap(:ok)
      nil

      iex> KineticLib.Result.unwrap({:error, 41})
      nil

      iex> KineticLib.Result.unwrap({:error, 41}, :unset)
      :unset
  """
  def unwrap(maybe_ok, default \\ nil)

  def unwrap({:ok, value}, _default) do
    value
  end

  def unwrap(value, _default) when is_ok(value) do
    [:ok | result] = Tuple.to_list(value)
    List.to_tuple(result)
  end

  def unwrap(_not_ok_tuple, default) do
    default
  end

  @doc ~S"""
  Returns the `value` stored in an `{:ok, value}` tuple or raises an exception.

  When provided value is not a `:ok` tuple, an exception will be raised. The
  exception message may be provided as a second parameter or extracted from an
  `{:error, reason}` tuple when `reason` is a string value. If there is no
  message, a standard message including the inspected `value` will be used.

  Tuples with more than one value element (`{:ok, value1, value2}`) will be
  unwrapped to value tuples (`{value1, value2}`). Single-element tuples
  (`{:ok}`) are treated regular values (resulting in the default return).

  ### Examples

      iex> KineticLib.Result.unwrap!({:ok, 42})
      42

      iex> KineticLib.Result.unwrap!({:ok, nil})
      nil

      iex> KineticLib.Result.unwrap!({:ok, {42, 43}})
      {42, 43}

      iex> KineticLib.Result.unwrap!({:ok, 42, 43})
      {42, 43}

      iex> KineticLib.Result.unwrap!(:ok)
      ** (KineticLib.Result.UnwrapError) term :ok is not an {:ok, value} tuple

      iex> KineticLib.Result.unwrap!({:ok})
      ** (KineticLib.Result.UnwrapError) term {:ok} is not an {:ok, value} tuple

      iex> KineticLib.Result.unwrap!({:error, 41})
      ** (KineticLib.Result.UnwrapError) term {:error, 41} is not an {:ok, value} tuple

      iex> KineticLib.Result.unwrap!({:error, "specific error message"})
      ** (KineticLib.Result.UnwrapError) specific error message

      iex> KineticLib.Result.unwrap!({:error, "specific error message"}, "other error message")
      ** (KineticLib.Result.UnwrapError) other error message
  """
  def unwrap!(value, message \\ nil) do
    case unwrap(value, {:unwrap_failure}) do
      {:unwrap_failure} ->
        params =
          if message do
            [message: message, term: value]
          else
            [term: value]
          end

        raise KineticLib.Result.UnwrapError, params

      unwrapped_value ->
        unwrapped_value
    end
  end

  @doc ~S"""
  Returns the `error` stored in an `{:error, value}` tuple, or returns the
  `default` value.

  Tuples with more than one error value element (`{:error, value1, value2}`)
  will be unwrapped to value tuples (`{value1, value2}`). Single-element tuples
  (`{:error}`) are treated regular values (resulting in the default return).

  ### Examples

      iex> KineticLib.Result.unwrap_error({:error, 41})
      41

      iex> KineticLib.Result.unwrap_error({:error, {42, 43}})
      {42, 43}

      iex> KineticLib.Result.unwrap_error({:error, 42, 43})
      {42, 43}

      iex> KineticLib.Result.unwrap_error({:error, nil})
      nil

      iex> KineticLib.Result.unwrap_error(:error, :unset)
      :unset

      iex> KineticLib.Result.unwrap_error({:error}, :unset)
      :unset

      iex> KineticLib.Result.unwrap_error({:ok, 71})
      nil

      iex> KineticLib.Result.unwrap_error({:ok, {42, 43}}, :unset)
      :unset
  """
  def unwrap_error(maybe_error, default \\ nil)

  def unwrap_error({:error, value}, _default) do
    value
  end

  def unwrap_error(value, _default) when is_error(value) do
    [:error | result] = Tuple.to_list(value)
    List.to_tuple(result)
  end

  def unwrap_error(_not_error_tuple, default) do
    default
  end

  @doc ~S"""
  Returns the `value` stored in an `{:error, value}` tuple or raises an
  exception.

  When provided value is not a `:error` tuple, an exception will be raised. The
  exception message may be provided as a second parameter. If not provided,
  a standard message including the inspected `value` will be used.

  Tuples with more than one value element (`{:error, value1, value2}`) will be
  unwrapped to value tuples (`{value1, value2}`). Single-element tuples
  (`{:error}`) are treated regular values (resulting in the default return).

  ### Examples

      iex> KineticLib.Result.unwrap_error!({:error, 41})
      41

      iex> KineticLib.Result.unwrap_error!({:error, {42, 43}})
      {42, 43}

      iex> KineticLib.Result.unwrap_error!({:error, 42, 43})
      {42, 43}

      iex> KineticLib.Result.unwrap_error!({:error, nil})
      nil

      iex> KineticLib.Result.unwrap_error!(:error)
      ** (KineticLib.Result.ErrorUnwrapError) term :error is not an {:error, value} tuple

      iex> KineticLib.Result.unwrap_error!({:error})
      ** (KineticLib.Result.ErrorUnwrapError) term {:error} is not an {:error, value} tuple

      iex> KineticLib.Result.unwrap_error!({:ok, 71})
      ** (KineticLib.Result.ErrorUnwrapError) term {:ok, 71} is not an {:error, value} tuple

      iex> KineticLib.Result.unwrap_error!({:ok, {42, 43}}, "error message")
      ** (KineticLib.Result.ErrorUnwrapError) error message
  """
  def unwrap_error!(value, message \\ nil) do
    case unwrap_error(value, {:unwrap_failure}) do
      {:unwrap_failure} ->
        params =
          if message do
            [message: message, term: value]
          else
            [term: value]
          end

        raise KineticLib.Result.ErrorUnwrapError, params

      unwrapped_value ->
        unwrapped_value
    end
  end

  @doc ~S"""
  Transforms a value into either `{:ok, value}` or `{:error, "not found"}`.

  Existing `:ok` or `:error` tuples will be unmodified, and `nil` and `:error`
  values will return `{:error, "not found"}` (or `{:error, reason}` if
  `[reason: reason]` is provided as the second argument).

  Like `ok/1` and `error/1`, existing `{:ok, …}` and `{:error, …}` tuples are
  passed unchanged. Unlike those functions, `new/2` will *conditionally* turn
  `Map.get/3` into a tuple-result or `Map.fetch/2` errors into a 2-tuple
  `{:error, reason}` result.

  ### Examples

      iex> KineticLib.Result.new(42)
      {:ok, 42}

      iex> KineticLib.Result.new(nil)
      {:error, "not found"}

      iex> KineticLib.Result.new(:ok)
      {:ok, :ok}

      iex> KineticLib.Result.new(:error)
      {:error, "not found"}

      iex> KineticLib.Result.new({:ok, 42})
      {:ok, 42}

      iex> KineticLib.Result.new({:ok, 42, 43})
      {:ok, 42, 43}

      iex> KineticLib.Result.new({:error, 41})
      {:error, 41}

      iex> KineticLib.Result.new({:error, 41, 42})
      {:error, 41, 42}

      iex> KineticLib.Result.new({:ok})
      {:ok, {:ok}}

      iex> KineticLib.Result.new({:error})
      {:ok, {:error}}

      iex> KineticLib.Result.new(nil, reason: "access denied")
      {:error, "access denied"}

      iex> KineticLib.Result.new(:error, reason: "access denied")
      {:error, "access denied"}

      iex> Map.get(%{h2g2: 42}, :h2g2) |> KineticLib.Result.new()
      {:ok, 42}

      iex> Map.fetch(%{h2g2: 42}, :vogon_poetry) |> KineticLib.Result.new(reason: "pure torture")
      {:error, "pure torture"}
  """
  def new(value, options \\ [])

  def new(value, _options) when is_result(value) do
    value
  end

  def new(value, options) when value in [:error, nil] do
    if reason = Keyword.get(options, :reason) do
      {:error, reason}
    else
      {:error, "not found"}
    end
  end

  def new(value, _options) do
    {:ok, value}
  end

  @doc ~S"""
  Unwraps all `{:ok, _}` values from a list of result tuples.

  The list of error values may be mixed and it is the responsibility of the
  caller to handle this.

  ### Examples

      iex> KineticLib.Result.unwrap_oks([{:ok, 1}, {:error, -13}, {:ok, 42}, {:ok}])
      [1, 42]

      iex> KineticLib.Result.unwrap_oks([{:ok, {1, 1}}, {:error, -13}, {:ok, 42, 71}, :ok])
      [{1, 1}, {42, 71}]

      iex> KineticLib.Result.unwrap_oks([{:error, -13}])
      []
  """
  def unwrap_oks(results) when is_list(results) do
    Enum.flat_map(results, fn
      result when is_ok(result) -> [unwrap(result)]
      _ -> []
    end)
  end

  @doc ~S"""
  Unwraps all `{:error, _}` values from a list of result tuples.

  The list of error values may be mixed and it is the responsibility of the
  caller to handle this.

  ### Examples

      iex> KineticLib.Result.unwrap_errors([{:error, 1}, {:ok, -13}, {:error, 42}, :error])
      [1, 42]

      iex> KineticLib.Result.unwrap_errors([{:error, {1, 1}}, {:ok, -13}, {:error, 42, 71}, {:error}])
      [{1, 1}, {42, 71}]

      iex> KineticLib.Result.unwrap_errors([{:ok, -13}])
      []
  """
  def unwrap_errors(results) when is_list(results) do
    Enum.flat_map(results, fn
      result when is_error(result) -> [unwrap_error(result)]
      _ -> []
    end)
  end

  @doc ~S"""
  Group oks and errors into a map with `:ok` and `:error` keys containing
  a list of results.

  This is the same result as, but more efficient than:

      %{
        ok: KineticLib.Result.unwrap_oks(list),
        errors: KineticLib.Result.unwrap_errors(list)
      }

  ### Examples
      iex> KineticLib.Result.group([{:error, 1}, {:ok, -13}, {:error, 42}, :ok])
      %{ok: [-13], error: [1, 42]}

      iex> KineticLib.Result.group([{:ok, {1, 1}}, {:error, -13}, {:ok, 42, 71}, {:ok}])
      %{error: [-13], ok: [{1, 1}, {42, 71}]}

      iex> KineticLib.Result.group([{:error, -13}])
      %{error: [-13], ok: []}
  """
  def group(results) do
    results
    |> Enum.reverse()
    |> Enum.reduce(%{ok: [], error: []}, fn
      result, acc when is_ok(result) -> %{acc | ok: [unwrap(result) | acc.ok]}
      result, acc when is_error(result) -> %{acc | error: [unwrap_error(result) | acc.error]}
      _, acc -> acc
    end)
  end
end
