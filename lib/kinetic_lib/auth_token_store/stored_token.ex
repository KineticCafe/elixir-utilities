defmodule KineticLib.AuthTokenStore.StoredToken do
  @moduledoc """
  A auth token response representation that is stored in the
  `KineticLib.AuthTokenStore`.
  """

  @typedoc """
  The stored credentials used to obtain or refresh the `token`.

  This is usually a map or a tuple, but the exact shape will be defined by the
  `provider`.
  """
  @type credentials :: term()

  @typedoc """
  The provider module which knows how to obtain or refresh the `token`.
  """
  @type provider :: module()

  @typedoc """
  The timestamp when this token was retrieved.

  This should be stored as UTC.

  If the `provider` API does not return an appropriate timestamp, the `provider`
  module should store the request time.
  """
  @type timestamp :: DateTime.t()

  @typedoc """
  The opaque token value represented as a binary value.

  This value will be inserted into requests.
  """
  @type token :: binary()

  @typedoc """
  The optional time-to-live for the token in seconds.

  If the `provider` API returns the TTL in a value other than seconds, it is
  the responsibility of the `provider` module to express this in seconds.
  """
  @type ttl :: pos_integer()

  @typedoc """
  The full representation of a token.
  """
  @type t() :: %__MODULE__{
          credentials: credentials,
          extra: any(),
          provider: provider,
          timestamp: nil | timestamp,
          token: token,
          ttl: nil | ttl
        }

  @derive {Inspect, except: [:credentials, :token]}
  @enforce_keys [:provider, :credentials, :token]

  defstruct [:provider, :credentials, :token, ttl: nil, timestamp: nil, extra: nil]

  @doc """
  Indicates whether the authentication token is valid.

  The `KineticLib.AuthTokenStore` will request a refreshed token from the
  `provider` if the current token is invalid.

  | `ttl`           | `timestamp`    | valid?    |
  | --------------- | -------------- | --------- |
  | `nil`           | n/a            | yes       |
  | `pos_integer()` | `nil`          | no        |
  | `pos_integer()` | `DateTime.t()` | computed  |

  If both `ttl` and `timestamp` are valid values, if the difference between the
  current time (UTC) and `timestamp` is less than or equal to `ttl` seconds,
  the token is valid.

  ### Best Practices

  If the `provider` API permits refreshing a token *earlier* than its TTL, we
  recommend that the `provider` module return the TTL as slightly shorter (1–5
  seconds) than that returned by the API.

  If the `provider` API does not return a TTL, we recommend synthesizing one.
  The recommended TTL is one hour (3,600 seconds), and for best security we do
  not recommend synthetic TTLs exceeding four hours (14,400 seconds).
  """
  def valid?(%__MODULE__{ttl: nil}), do: true
  def valid?(%__MODULE__{timestamp: nil}), do: false

  def valid?(%__MODULE__{timestamp: %DateTime{} = timestamp, ttl: ttl}) do
    DateTime.diff(DateTime.utc_now(), timestamp, :second) <= ttl
  end
end
