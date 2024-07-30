defmodule KineticLib.ConfigCache do
  @moduledoc """
  `KineticLib.ConfigCache` is a write-once node persistent cache of frequently
  used configuration values, best used when a complex or expensive
  transformation is required to use the configuration values. The storage is
  provided by [`:persistent_term`][1], and the implications of that should be
  understood before using this module.

  > #### No Data Expiration {: .warning}
  >
  > This is not a typical cache with automated data expiration. The data is
  > cached as long as the server is running and never expires. It is intended
  > for items which change infrequently and for which a staged application
  > restart would be sufficient to force a refresh (such as application
  > tokens, etc.).
  >
  > This should not be used for anything that could be updated and needs
  > immediate response to that update.

  [1]: https://www.erlang.org/doc/man/persistent_term.html
  """

  @typedoc """
  A key to use for `:persistent_term`. This must be a tuple with at least two
  values.
  """
  @type key :: tuple()

  @type fetch_function :: (-> {:ok, term()} | {:error, any()} | term())

  @doc """
  Retrieves the item from `:persistent_term` using `key`, or stores and returns
  the result of the `fetch_function`.

  The `fetch_function` *must* return `{:ok, term()}` to be considered
  successful. If `{:error, any()}` is returned from the `fetch_function`, that
  will be returned; any other value will result in `:error`.

  Default or fallback values should be handled by the calling function, as
  default values should not be cached.

  ## Examples

  The key must be a tuple at least size 2.

      iex> fetch_or_store(:not_a_tuple, fn -> true end)
      ** (FunctionClauseError) no function clause matching in KineticLib.ConfigCache.fetch_or_store/2

      iex> fetch_or_store({1}, fn -> true end)
      ** (FunctionClauseError) no function clause matching in KineticLib.ConfigCache.fetch_or_store/2

  The `fetch_function` must return `{:ok, term()}` to succeed.

      iex> fetch_or_store({KineticLib.ConfigCache, "key"}, fn -> :set end)
      :error

  The `fetch_function` may return `{:error, any()}` and it will be propagated.

      iex> fetch_or_store({KineticLib.ConfigCache, "key"}, fn -> {:error, :propagation} end)
      {:error, :propagation}

  The value is cached in `:persistent_term`.

      iex> :persistent_term.get({KineticLib.ConfigCache, "key"}, :unset)
      :unset
      iex> fetch_or_store({KineticLib.ConfigCache, "key"}, fn -> {:ok, :set} end)
      {:ok, :set}
      iex> :persistent_term.get({KineticLib.ConfigCache, "key"}, :unset)
      :set

  The value is persisted even if the return from `fetch_function` changes.

      iex> fetch_or_store({KineticLib.ConfigCache, "key"}, fn -> {:ok, :set} end)
      {:ok, :set}
      iex> :persistent_term.get({KineticLib.ConfigCache, "key"}, :unset)
      :set
      iex> fetch_or_store({KineticLib.ConfigCache, "key"}, fn -> {:ok, :reset} end)
      {:ok, :set}
  """
  def fetch_or_store(key, fetch_function) when is_tuple(key) and tuple_size(key) >= 2 do
    case :persistent_term.get(key, {:error, __MODULE__}) do
      {:error, __MODULE__} ->
        case fetch_function.() do
          {:ok, value} ->
            :persistent_term.put(key, value)
            {:ok, value}

          {:error, reason} ->
            {:error, reason}

          _anything_else ->
            :error
        end

      value ->
        {:ok, value}
    end
  end
end
