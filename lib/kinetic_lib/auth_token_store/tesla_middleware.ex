defmodule KineticLib.AuthTokenStore.TeslaMiddleware do
  @moduledoc """
  A `Tesla.Middleware` which handles requesting and caching authorization
  tokens, and adding them as a request header.

  ## Example

  This middleware always requires configuration and may only be used as
  a runtime middleware.

  It may be configured with a `{provider, term}` tuple (where `provider`
  implements the `KineticLib.AuthTokenStore.Provider` behaviour) and any term that
  represents the credentials the provider requires.

  ```
    Tesla.client([
      {KineticLib.AuthTokenStore.TeslaMiddleware,
        {TokenProvider, {catalog, app, client_id, secret}}}
    ])
  ```

  Advanced configuration may be provided with a configuration map that must
  contain the `provider` and `credentials` keys:

  ```
    Tesla.client([
      {KineticLib.AuthTokenStore.TeslaMiddleware,
        %{
          provider: TokenProvider,
          credentials: {catalog, app, api_key, client_secret, base_url},
          invalidate_unauthorized: true,
          retry_after_invalidate: true
        }
      }
    ])
  ```

  ## Options

  - `:invalidate_unauthorized`: removes token if response is a 401 Unauthorized
    (default: false)

  - `:retry_after_invalidate`: whether the request which failed via a 401
    should be retried after getting a new token. Only used if
    `invalidate_unauthorized` is also true. (default: false)
  """

  @behaviour Tesla.Middleware

  alias KineticLib.AuthTokenStore
  alias KineticLib.AuthTokenStore.StoredToken

  @type options ::
          %{
            required(:provider) => module(),
            required(:credentials) => term() | (-> term()),
            optional(:invalidate_unauthorized) => boolean(),
            optional(:retry_after_invalidate) => boolean()
          }
          | {module(), term() | (-> term())}

  def call(env, next, {provider, credentials}) do
    call(env, next, %{provider: provider, credentials: credentials})
  end

  def call(env, next, %{provider: _, credentials: _} = opts) do
    do_request(env, next, opts, true)
  end

  def call(_env, _next, _opts) do
    message = "#{__MODULE__} is missing required args"
    KineticLib.record_error_message(message)
    {:error, message}
  end

  defp do_request(env, next, %{provider: provider, credentials: credentials} = opts, first?) do
    case AuthTokenStore.request(provider, credentials) do
      {:ok, %StoredToken{token: token_value} = token} ->
        auth_header =
          if function_exported?(provider, :authorization_header, 1) do
            provider.authorization_header(token)
          else
            {"authorization", "Bearer #{token_value}"}
          end

        env
        |> Tesla.put_headers([auth_header])
        |> Tesla.run(next)
        |> handle_response(env, next, opts, first?)

      error ->
        error
    end
  end

  defp handle_response(
         {:ok, %{status: 401}} = response,
         env,
         next,
         opts,
         first?
       ) do
    if Map.get(opts, :invalidate_unauthorized, false) do
      invalidate_token_and_maybe_retry(response, env, next, opts, first?)
    else
      response
    end
  end

  defp handle_response(response, _env, _next, _opts, _first?) do
    response
  end

  defp invalidate_token_and_maybe_retry(
         response,
         env,
         next,
         %{provider: provider, credentials: credentials} = opts,
         first?
       ) do
    AuthTokenStore.release(provider, credentials)

    if first? and Map.get(opts, :retry_after_invalidate, false) do
      do_request(env, next, opts, false)
    else
      response
    end
  end
end
