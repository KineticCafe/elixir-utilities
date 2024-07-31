if Code.loaded?(Tesla) do
  defmodule KineticLib.SFMC.AuthTokenProvider do
    @moduledoc """
    An authentication token provider for SFMC for use with `KineticLib.AuthTokenStore`.
    Supports both "legacy" (v1) and "enhanced" (v2) authentication methods.

    This is currently only written to use Tesla and is provided as an example
    implementation.
    """

    @behaviour KineticLib.AuthTokenStore.Provider

    @callback parse_response_body(
                response :: {:ok, term()} | term(),
                provider :: module(),
                credentials :: term()
              ) :: {:ok, KineticLib.AuthTokenStore.StoredToken.t()} | {:error, term()}

    @callback url(struct()) :: String.t()

    @callback valid?(struct()) :: boolean()

    @callback clean_credentials(term()) :: map()

    defmodule V1 do
      @moduledoc "SFMC Legacy Package Authentication Config"

      @behaviour KineticLib.SFMC.TokenProvider

      @type t :: %__MODULE__{}
      @derive {Inspect, except: [:client_secret]}
      @enforce_keys [:client_id, :client_secret]

      defstruct [:client_id, :client_secret, :url]

      @impl true
      def parse_response_body(
            {:ok, %{body: %{"accessToken" => access_token, "expiresIn" => ttl}}},
            provider,
            credentials
          ) do
        {:ok,
         %KineticLib.AuthTokenStore.StoredToken{
           provider: provider,
           credentials: credentials,
           token: access_token,
           ttl: ttl
         }}
      end

      def parse_response_body(_response, _provider, _credentials) do
        {:error, "invalid response to token request"}
      end

      @impl true
      def url(%__MODULE__{url: nil}) do
        "https://auth.exacttargetapis.com/v1/requestToken"
      end

      def url(%__MODULE__{url: url}) do
        url
      end

      @impl true
      def valid?(%__MODULE__{client_id: id, client_secret: secret, url: url}) do
        not is_nil(id) and not is_nil(secret) and
          (is_nil(url) or String.starts_with?(url, "https://"))
      end

      def valid?(_) do
        false
      end

      @impl true
      def clean_credentials(%__MODULE__{client_id: id, url: url}) do
        %{client_id: id, url: url, client_secret: "[Filtered]"}
      end

      defimpl Jason.Encoder do
        def encode(value, opts) do
          Jason.Encode.map(
            %{"clientId" => value.client_id, "clientSecret" => value.client_secret},
            opts
          )
        end
      end
    end

    defmodule V2 do
      @moduledoc "SFMC Enhanced Package Authentication Config"

      @behaviour KineticLib.SFMC.TokenProvider

      @type t :: %__MODULE__{}
      @derive {Inspect, except: [:client_secret]}
      @enforce_keys [:client_id, :client_secret]

      defstruct [
        :account_id,
        :client_id,
        :client_instance_id,
        :client_secret,
        :grant_type,
        :scope,
        :url
      ]

      @impl true
      def parse_response_body(
            {:ok, %{body: %{"access_token" => _, "expires_in" => _} = body}},
            provider,
            credentials
          ) do
        {:ok,
         %KineticLib.AuthTokenStore.StoredToken{
           provider: provider,
           credentials: credentials,
           token: body["access_token"],
           ttl: body["expires_in"],
           extra: %{
             "type" => body["token_type"],
             "scope" => String.split(body["scope"] || "", " "),
             "rest_instance_url" => body["rest_instance_url"],
             "soap_instance_url" => body["soap_instance_url"]
           }
         }}
      end

      def parse_response_body(_response, _provider, _credentials) do
        {:error, "invalid response to token request"}
      end

      @impl true
      def url(%__MODULE__{url: nil, client_instance_id: id}) do
        "https://#{id}.auth.marketingcloudapis.com/v2/Token"
      end

      def url(%__MODULE__{url: url}) do
        url
      end

      @impl true
      def valid?(%__MODULE__{
            client_id: id,
            client_instance_id: instance,
            client_secret: secret,
            url: url
          }) do
        not is_nil(id) and not is_nil(secret) and
          ((not is_nil(url) and String.starts_with?(url, "https://")) or
             not is_nil(instance))
      end

      def valid?(_) do
        false
      end

      @impl true
      def clean_credentials(%__MODULE__{} = credentials) do
        credentials
        |> Map.from_struct()
        |> Enum.reject(&match?({_k, nil}, &1))
        |> Map.new()
        |> Map.take([:account_id, :client_id, :client_instance_id, :grant_type, :scope, :url])
        |> Map.put(:client_secret, "[Filtered]")
      end

      defimpl Jason.Encoder do
        def encode(value, opts) do
          Jason.Encode.map(
            value
            |> Map.from_struct()
            |> Enum.reject(&match?({_k, nil}, &1))
            |> Map.new()
            |> Map.put_new(:grant_type, "client_credentials"),
            opts
          )
        end
      end
    end

    @impl true
    def name do
      "SFMC Token Provider"
    end

    @impl true
    def description do
      """
      Provides authentication tokens for SFMC APIs. Both legacy and enhanced
      package authentication requests are supported.
      """
    end

    @impl true
    def request_token(client \\ nil, %mod{} = credentials) when mod in [V1, V2] do
      if mod.valid?(credentials) do
        client
        |> perform_request(credentials)
        |> mod.parse_response_body(__MODULE__, credentials)
      else
        {:error, "invalid token configuration: #{inspect(credentials)}"}
      end
    end

    @impl true
    def clean_credentials(%mod{} = credentials) when mod in [V1, V2] do
      if mod.valid?(credentials) do
        mod.clean_credentials(credentials)
      else
        %{mode: to_string(mod), invalid: "provided credentials are not valid"}
      end
    end

    defp perform_request(client, %mod{} = credentials) do
      Tesla.post(build_client(client), mod.url(credentials), credentials)
    end

    defp build_client(%Tesla.Client{} = client) do
      client
    end

    defp build_client(_) do
      middleware = [
        {Tesla.Middleware.Timeout, timeout: 30_000},
        Tesla.Middleware.Compression,
        Tesla.Middleware.JSON,
        Tesla.Middleware.Logger
      ]

      adapter = {Tesla.Adapter.Hackney, ssl_options: [{:versions, [:"tlsv1.2"]}]}

      Tesla.client(middleware, adapter)
    end
  end
end
