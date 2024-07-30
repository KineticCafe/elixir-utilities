defmodule KineticLib.Scytale do
  @moduledoc """
  `KineticLib.Scytale` provides XChaCha20Poly1305 encryption and decryption for
  messages.

  Scytale provides `encrypt/4` and `decrypt/4` functions similar to
  `Plug.Crypto.encrypt/4` and `Plug.decrypt/4`, but disables message age
  verification by default and provides some support for increasing message or
  key security parameters with tuple secret parameters.

  This module is named after a Greek [scytale][1], a physical device to provide
  a transposition cypher.

  [1] https://en.wikipedia.org/wiki/Scytale
  """

  secret_tuple = """
  The `secret` parameter may be a non-empty tuple indicating a sensitivity
  level and optional additional values. The entire tuple will be converted into
  a binary salt and the first element of the tuple is treated as a level to
  provide stricter default key derivation parameters.

  | level       | minimum iterations | digest   |
  | ----------- | ------------------ | -------- |
  | `personal`  |             `2000` | `sha256` |
  | `sensitive` |             `5000` | `sha384` |
  | `medical`   |            `10000` | `sha384` |
  | *           |             `1000` | `sha256` |

  The key digest can be overridden with the `key_digest` option, but if any
  sensitivity level is provided, `key_iterations` cannot be set to a smaller
  value.
  """

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageEncryptor

  defguardp is_valid_secret(secret)
            when is_binary(secret) or (is_tuple(secret) and tuple_size(secret) > 1)

  @doc """
  Encodes, encrypts, and signs `data` into a payload that can be stored
  in the database.

      KineticLib.Scytale.encrypt(secret_key_base, user_secret, term)

  An encryption key will be derived from `secret_key_base` and a given user
  `secret` value. The key may be cached using an ETS table name passed as the
  `cache` option. See `Plug.Crypt.KeyGenerator.generate/3`.

  #{secret_tuple}

  ## Options

  - `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator` when
    generating the encryption and signing keys. Defaults to 1000.
  - `:key_length` - option passed to `Plug.Crypto.KeyGenerator` when generating
    the encryption and signing keys. Defaults to 32
  - `:key_digest` - option passed to `Plug.Crypto.KeyGenerator` when generating
    the encryption and signing keys. Defaults to `:sha256`
  - `:signed_at` - set the timestamp of the token in seconds. Defaults to
    `System.os_time(:millisecond)`
  - `:max_age` - the default maximum age of the token. Defaults to `:infinity`.
    This value may be overridden on `decrypt/4`.
  """
  def encrypt(secret_key_base, secret, data, opts \\ [])
      when is_binary(secret_key_base) and is_valid_secret(secret) do
    data
    |> encode(opts)
    |> MessageEncryptor.encrypt(get_secret(secret_key_base, secret, opts), "")
  end

  @doc """
  Decrypts the original data from the `payload` and verifies its integrity.

  An encryption key will be derived from `secret_key_base` and a given user
  `secret` value. The key may be cached using an ETS table name passed as the
  `cache` option. See `Plug.Crypt.KeyGenerator.generate/3`.

  #{secret_tuple}

  ## Options

  - `:max_age` - verifies the payload only if it has been generated "max age"
    ago in seconds. If not provided, or if the value `:infinity` is provided,
    the payload never expires.
  - `:key_iterations` - option passed to `Plug.Crypto.KeyGenerator` when
    generating the encryption and signing keys. Defaults to 1000.
  - `:key_length` - option passed to `Plug.Crypto.KeyGenerator` when generating
    the encryption and signing keys. Defaults to 32.
  - `:key_digest` - option passed to `Plug.Crypto.KeyGenerator` when generating
    the encryption and signing keys. Defaults to `:sha256`.
  """
  def decrypt(secret_key_base, secret, payload, opts \\ [])

  def decrypt(secret_key_base, secret, nil, opts)
      when is_binary(secret_key_base) and is_list(opts) and
             is_valid_secret(secret) do
    {:error, :missing}
  end

  def decrypt(secret_key_base, secret, payload, opts)
      when is_binary(secret_key_base) and is_list(opts) and is_valid_secret(secret) do
    secret = get_secret(secret_key_base, secret, opts)

    case MessageEncryptor.decrypt(payload, secret, "") do
      {:ok, message} -> decode(message, opts)
      :error -> {:error, :invalid}
    end
  end

  defp encode(data, opts) do
    signed_at_seconds = Keyword.get(opts, :signed_at)
    signed_at_ms = if signed_at_seconds, do: trunc(signed_at_seconds * 1000), else: now_ms()
    max_age_in_seconds = Keyword.get(opts, :max_age, :infinity)
    :erlang.term_to_binary({data, signed_at_ms, max_age_in_seconds})
  end

  defp decode(message, opts) do
    case Plug.Crypto.non_executable_binary_to_term(message) do
      {data, signed, max_age} ->
        if expired?(signed, Keyword.get(opts, :max_age, max_age)) do
          {:error, :expired}
        else
          {:ok, data}
        end

      _ ->
        {:error, :invalid}
    end
  end

  defp get_secret(secret, salt, opts) do
    {salt, {iterations, length, digest, cache}} = get_salt_options(salt, opts)

    KeyGenerator.generate(secret, salt, iterations, length, digest, cache)
  end

  defp get_salt_options(salt, opts) when is_binary(salt) do
    {salt, get_options(opts)}
  end

  defp get_salt_options(salt, opts) when is_tuple(salt) and tuple_size(salt) > 0 do
    opts = update_salt_options(elem(salt, 0), opts)
    salt = Enum.join(Tuple.to_list(salt), ".")

    {salt, get_options(opts)}
  end

  defp get_options(opts) do
    {
      Keyword.get(opts, :key_iterations, 1000),
      Keyword.get(opts, :key_length, 32),
      Keyword.get(opts, :key_digest, :sha256),
      Keyword.get(opts, :cache)
    }
  end

  defp update_salt_options(level, opts) when level in ["personal", :personal] do
    set_minimum_key_iterations(opts, 2000)
  end

  defp update_salt_options(level, opts) when level in ["sensitive", :sensitivte] do
    opts
    |> Keyword.put_new(:key_digest, :sha384)
    |> set_minimum_key_iterations(5000)
  end

  defp update_salt_options(level, opts) when level in ["medical", :medical] do
    opts
    |> Keyword.put_new(:key_digest, :sha384)
    |> set_minimum_key_iterations(10_000)
  end

  defp update_salt_options(_level, opts) do
    set_minimum_key_iterations(opts, 1000)
  end

  defp set_minimum_key_iterations(opts, minimum) do
    Keyword.update(opts, :key_iterations, minimum, &if(&1 >= minimum, do: &1, else: minimum))
  end

  defp expired?(_signed, :infinity), do: false
  defp expired?(_signed, max_age_secs) when max_age_secs <= 0, do: true
  defp expired?(signed, max_age_secs), do: signed + trunc(max_age_secs * 1000) < now_ms()

  defp now_ms, do: System.os_time(:millisecond)
end
