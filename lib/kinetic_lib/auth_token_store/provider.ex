defmodule KineticLib.AuthTokenStore.Provider do
  @moduledoc """
  A TokenProvider implements several functions that allow it to request and/or
  refresh a token that will be stored in `KineticLib.AuthTokenStore`.
  """

  alias KineticLib.AuthTokenStore.StoredToken

  @doc "Returns the name of the token provider."
  @callback name() :: String.t()

  @doc "Returns a description of the token provider."
  @callback description() :: String.t()

  @doc "Given credentials, returns a valid token."
  @callback request_token(term()) :: Kinetic.result(StoredToken.t())

  @doc """
  Given an expiring token, refreshes the token. This callback is optional, as
  not all APIs provide refresh functionality.
  """
  @callback refresh_token(StoredToken.t()) :: Kinetic.result(StoredToken.t())

  @doc """
  Returns the expected timeout for the provider. If present and non-nil, this
  will be _added_ to the timeout provided as a parameter to
  `KineticLib.AuthTokenStore.request/{3,4}`. This will prevent a timeout if
  the request always takes longer than the requested timeout.
  """
  @callback timeout() :: nil | non_neg_integer()

  @doc """
  Returns a tuple of token header and value suitable for adding to a request.

  If defined, this callback should implement versions that handle both
  `t:StoredToken.t/0` and `t:String.t/0` to return the header tuple like
  `{"authorization", "Bearer {token}"}`.

  Used by `KineticLib.AuthTokenStore.TeslaMiddleware` if defined.
  """
  @callback authorization_header(String.t() | StoredToken.t()) :: {String.t(), String.t()}

  @doc """
  Returns a version of the credentials that does not contains sensitive data in
  order to assist debugging.
  """
  @callback clean_credentials(term()) :: map()

  @optional_callbacks description: 0, refresh_token: 1, timeout: 0, authorization_header: 1
end
