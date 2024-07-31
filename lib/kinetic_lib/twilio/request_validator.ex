defmodule KineticLib.Twilio.RequestValidator do
  @moduledoc """
  Validates that a request received from Twilio is authentic using Twilio's
  [request-signing algorithm][rsa].

  Based heavily on the [Ruby implementation][ruby].

  [rsa]: https://www.twilio.com/docs/usage/security#validating-requests
  [ruby]: https://github.com/twilio/twilio-ruby/blob/main/lib/twilio-ruby/security/request_validator.rb
  """

  @typedoc """
  Twilio resource SIDs.
  """
  @type sid :: binary()

  @typedoc """
  A function that returns the value of the secret stored in it.
  """
  @type secret :: (-> binary())

  @type auth_token ::
          binary()
          | secret()
          | %{required(:auth_token) => binary() | secret(), optional(term()) => term()}
  @type auth_token_locator :: (sid() -> auth_token) | {module(), atom(), list(term())}

  @doc """
  Verifies the provided `signature` against the cryptographically computed
  signature from the request URL, parameters, and Twilio `AuthToken` value.

  ### Parameters

  - `signature`: The signature to be verified, pulled from the request header
    `x-twilio-signature`.

  - `auth_token`: The Twilio `AuthToken` value for validating this request.
    This may be provided as any of the following formats:

    1. the binary string token;
    2. a `t:secret/0` function returning the binary string token;
    3. a `t:map/0` with the key `:auth_token` that contains either of the above
       values; or
    4. a locator `function/1` or `{module, function, args}` that accepts the
       `AccountSid` parameter and returns any of the above values.

       The `{module, function, args}` form will have the `AccountSid` parameter
       prepended to the call.

    The first two formats are *preferred* so that the *caller* of `valid?/1`
    performs any resolution.

  - `request_url`: The URL sent to your server, including any query parameters.
    This will typically be the value from `Plug.Conn.request_url/1`.

  - `params_or_body`: The value expected for this parameter varies based on the
    Twilio webhook configuration, of which there are three variations:

    1. `GET` requests must pass `nil` or `""`.
    2. `POST` requests with an `application/x-www-form-urlencoded` body must
       pass `conn.body_params`.
    3. `POST` requests with any other encoding must pass the unparsed body
       string. There will be a query parameter, `bodySHA256` that will contain
       the SHA256 hash of the body for comparison.
  """
  def valid?(signature, auth, url, params_or_body) do
    {url, query_params} = resolve_url(url)

    with {:ok, params} <- __check_params_or_body(params_or_body, query_params),
         {:ok, auth_token} <- __resolve_auth_token(auth, params, query_params) do
      check(signature, auth_token, url, params)
    else
      _anything_else -> false
    end
  end

  # 1. binary
  def __resolve_auth_token(auth_token, _params, _query_params) when is_binary(auth_token),
    do: {:ok, auth_token}

  # 2. secret()
  def __resolve_auth_token(auth_token, _params, _query_params)
      when is_function(auth_token, 0),
      do: {:ok, auth_token.()}

  # 3. %{required(:auth_token) => binary()}
  def __resolve_auth_token(%{auth_token: auth_token}, params, query_params),
    do: __resolve_auth_token(auth_token, params, query_params)

  # 4. auth_token_locator (function/1)
  def __resolve_auth_token(auth_token_locator, params, query_params)
      when is_function(auth_token_locator, 1) do
    case get_account_sid(params, query_params) do
      {:ok, account_sid} ->
        __resolve_auth_token(auth_token_locator.(account_sid), %{}, %{})

      :error ->
        :error
    end
  end

  # 4. auth_token_locator (mfa)
  def __resolve_auth_token({module, function, args}, params, query_params) do
    case get_account_sid(params, query_params) do
      {:ok, account_sid} ->
        __resolve_auth_token(apply(module, function, [account_sid | args]), %{}, %{})

      :error ->
        :error
    end
  end

  def __resolve_auth_token(_auth_token, _body_params, _query_params), do: :error

  def __build_signature(auth_token, url, params) do
    params_string =
      case params do
        nil ->
          ""

        %{} ->
          params
          |> Map.keys()
          |> Enum.sort()
          |> Enum.map_join(&(&1 <> Map.get(params, &1)))
      end

    data = url <> params_string

    :hmac
    |> :crypto.mac(:sha, auth_token, data)
    |> Base.encode64()
    |> String.trim()
  end

  def __check_params_or_body(nil, _query_params), do: {:ok, nil}
  def __check_params_or_body("", _query_params), do: {:ok, nil}
  def __check_params_or_body(%{} = params, _query_params), do: {:ok, params}

  def __check_params_or_body(body, query_params) when is_binary(body) do
    case Map.fetch(query_params, "bodySHA256") do
      :error ->
        :error

      {:ok, body_sha256} when is_binary(body_sha256) and byte_size(body_sha256) > 0 ->
        body_hash =
          :sha256
          |> :crypto.hash(body)
          |> Base.encode16(case: :lower)

        if KineticLib.secure_compare(body_sha256, body_hash) do
          {:ok, nil}
        else
          :error
        end

      _anything_else ->
        :error
    end
  end

  defp get_account_sid(params, query_params) do
    case Map.fetch(params, "AccountSID") do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(query_params, "AccountSID")
    end
  end

  defp resolve_url(url) when is_binary(url), do: resolve_url(URI.parse(url))
  defp resolve_url(%URI{query: nil} = url), do: {url, %{}}
  defp resolve_url(%URI{query: query} = url), do: {url, Map.new(URI.query_decoder(query))}

  defp check(signature, auth_token, url, params) do
    # Build port variants for validation. Twilio's signature validation is
    # inconsistent as to whether it includes the default port or not, so we
    # need variants with and without the ports. If Phoenix is not running with
    # HTTPS enabled internally, the scheme is `http` from
    # Plug.Conn.request_url/1. Therefore, we should test with both `http` and
    # `https`, although `https` is likely to be the correct version almost all
    # cases.
    url_variants = [
      add_port(%{url | scheme: "https"}),
      remove_port(%{url | scheme: "https"}),
      add_port(%{url | scheme: "http"}),
      remove_port(%{url | scheme: "http"})
    ]

    Enum.any?(url_variants, &compare_signatures(auth_token, &1, params, signature))
  end

  defp compare_signatures(auth_token, url, params, signature) do
    auth_token
    |> __build_signature(url, params)
    |> KineticLib.secure_compare(signature)
  end

  defp remove_port(uri), do: URI.to_string(%{uri | port: nil})

  defp add_port(%{scheme: scheme, port: port} = uri) do
    if scheme && (is_nil(port) || port == URI.default_port(scheme)) do
      to_uri_string_with_port(%{uri | port: URI.default_port(scheme)})
    else
      URI.to_string(uri)
    end
  end

  # Lifted from elixir/lib/uri.ex:1032-1065
  defp to_uri_string_with_port(
         %{scheme: scheme, path: path, query: query, fragment: fragment} = uri
       ) do
    authority = extract_authority(uri)

    IO.iodata_to_binary([
      if(scheme, do: [scheme, ?:], else: []),
      if(authority, do: [?/, ?/ | authority], else: []),
      if(path, do: path, else: []),
      if(query, do: [?? | query], else: []),
      if(fragment, do: [?# | fragment], else: [])
    ])
  end

  defp extract_authority(%{host: nil, authority: authority}), do: authority

  defp extract_authority(%{host: host, userinfo: userinfo, port: port}) do
    # According to the grammar at
    # https://tools.ietf.org/html/rfc3986#appendix-A, a "host" can have a colon
    # in it only if it's an IPv6 or "IPvFuture" address, so if there's a colon
    # in the host we can safely surround it with [].
    [
      if(userinfo, do: [userinfo | "@"], else: []),
      if(String.contains?(host, ":"), do: ["[", host | "]"], else: host),
      if(port, do: [":" | Integer.to_string(port)], else: [])
    ]
  end
end
