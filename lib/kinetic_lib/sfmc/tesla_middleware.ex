if Code.loaded?(Tesla) do
  defmodule KineticLib.SFMC.TeslaMiddleware do
    @moduledoc """
    A `Tesla.Middleware` which handles requesting and caching authorization tokens
    for SFMC APIs, adding them as a request header, and dynamically setting the
    request base URL.

    This is based on `KineticLib.AuthTokenStore.TeslaMiddleware`. It has one
    parameter required, the credentials, which must be either
    `KineticLib.SFMC.TokenProvider.V1` or `KineticLib.SFMC.TokenProvider.V2`
    structs.
    """

    @behaviour Tesla.Middleware

    alias KineticLib.AuthTokenStore
    alias KineticLib.AuthTokenStore.StoredToken
    alias KineticLib.SFMC.TokenProvider

    @type credentials :: TokenProvider.V1.t() | TokenProvider.V2.t()

    def call(env, next, %mod{} = credentials) when mod in [TokenProvider.V1, TokenProvider.V2] do
      do_request(env, next, credentials)
    end

    def call(_env, _next, _credentials) do
      {
        :error,
        "#{__MODULE__} requires credentials as either " <>
          "`KineticLib.SFMC.TokenProvider.V1` or " <>
          "`KineticLib.SFMC.TokenProvider.V2` structs."
      }
    end

    defp do_request(env, next, credentials) do
      do_request(env, next, credentials, true)
    end

    defp do_request(env, next, credentials, first?) do
      case AuthTokenStore.request(TokenProvider, credentials) do
        {:ok, %StoredToken{} = token} ->
          env
          |> Tesla.put_headers([{"authorization", token_header(token)}])
          |> Tesla.Middleware.BaseUrl.call(next, base_url(token))
          |> handle_response(env, next, credentials, first?)

        error ->
          error
      end
    end

    defp token_header(%StoredToken{credentials: %TokenProvider.V1{}, token: token}) do
      "Bearer #{token}"
    end

    defp token_header(%StoredToken{
           credentials: %TokenProvider.V2{},
           extra: %{"type" => type},
           token: token
         }) do
      type <> " " <> token
    end

    defp base_url(%StoredToken{credentials: %TokenProvider.V1{}}) do
      "https://www.exacttargetapis.com"
    end

    defp base_url(%StoredToken{
           credentials: %TokenProvider.V2{},
           extra: %{"rest_instance_url" => url}
         }) do
      if String.starts_with?(url, "https://") do
        url
      else
        "https://#{url}"
      end
    end

    defp handle_response(
           {:ok, %{status: 401}} = response,
           env,
           next,
           credentials,
           first?
         ) do
      AuthTokenStore.release(TokenProvider, credentials)

      if first? do
        do_request(env, next, credentials, false)
      else
        response
      end
    end

    defp handle_response(response, _env, _next, _credentials, _first?) do
      response
    end
  end
end
