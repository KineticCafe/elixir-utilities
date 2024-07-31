if Code.loaded?(Plug) do
  defmodule KineticLib.Plug.ShopifyWebhook do
    @shopify_hmac_header "x-shopify-hmac-sha256"
    @shopify_topic_header "x-shopify-topic"
    @shopify_domain_header "x-shopify-shop-domain"

    @moduledoc """
    This plug must be used in conjunction with `KineticLib.Plug.BodyCaching` in order to
    have access to the raw body for validation.

    It is recommended that this plug be placed in an appropriate sub-router or controller
    so that if there are multiple Shopify configurations to use, this plug is configured
    with the correct `:secret_key`. Otherwise, this plug can be configured with
    `:secret_key_loader` to resolve based on provided path parameters or other values.

    Regardless of how it is plugged into your pipelines, it will only run if
    `#{@shopify_hmac_header}` is present.

    Successful validation will add the first found values from
    `#{@shopify_topic_header}` and `#{@shopify_domain_header}` to
    `conn.assigns.shopify_topic` and `conn.assigns.shopify_shop_domain`,
    respectively.

    ## Options

    - `:secret_key`: A statically configured Shopify secret for computing the
      HMAC for validation.

      May also be provided as `{old_secret, new_secret}` and both secrets will be
      tested. The `old_secret` value may be `nil`.

          plug KineticWeb.Plugs.ShopifyWebhook,
            secret_key: Application.get_env(:my_application, :shopify).webhook_secret_key

    - `:secret_key_loader`: A `function/1` accepting `conn` and returning the
      secret key or secret key pair to use for HMAC calculation. May also be
      specified as `{module, function, args}`.

          plug KineticLib.Plug.ShopifyWebhook,
            secret_key_loader: {MyApp, :shopify_secret_key, []}

          plug KineticLib.Plug.ShopifyWebhook,
            secret_key_loader: &MyApp.shopify_secret_key/1
    """

    alias Plug.Conn

    require Logger

    @behaviour Plug

    @type secret_key :: binary() | {nil | binary(), binary()}
    @type secret_key_loader :: (Conn.t() -> secret_key) | {module(), atom(), list(term())}
    @type option :: {:secret_key, secret_key} | {:secret_key_loader, secret_key_loader}

    @impl true
    def init(options) do
      secret_key = get_secret_key(options)
      secret_key_loader = get_secret_key_loader(options)

      case {is_nil(secret_key), is_nil(secret_key_loader)} do
        {true, true} ->
          raise "one of `secret_key` or `secret_key_loader` must be specified"

        {false, false} ->
          raise "only one of `secret_key` or `secret_key_loader` may be specified"

        _anything_else ->
          {secret_key, secret_key_loader}
      end
    end

    @impl true
    def call(conn, {_, _} = config) do
      case Conn.get_req_header(conn, @shopify_hmac_header) do
        [signature | _] -> dispatch(conn, signature, config)
        _ -> conn
      end
    end

    def get_secret_key(options) do
      case Keyword.fetch(options, :secret_key) do
        :error ->
          nil

        {:ok, secret_key} when is_binary(secret_key) ->
          secret_key

        {:ok, {old_secret_key, new_secret_key}}
        when is_binary(old_secret_key) and is_binary(new_secret_key) ->
          {old_secret_key, new_secret_key}

        _anything_else ->
          raise "`secret_key` option must be a binary string or `{old_secret_key, new_secret_key}`"
      end
    end

    def get_secret_key_loader(options) do
      case Keyword.fetch(options, :secret_key_loader) do
        :error ->
          nil

        {:ok, {m, f, a}} when is_atom(m) and is_atom(f) and is_list(a) ->
          {m, f, a}

        {:ok, function} when is_function(function, 1) ->
          function

        _anything_else ->
          raise "`secret_key_loader` option must be `{module, function, args}` or `function/1`"
      end
    end

    defp dispatch(conn, signature, {key, nil}), do: perform_validation(conn, signature, key)

    defp dispatch(conn, signature, {nil, loader}),
      do: perform_validation(conn, signature, loader.(conn))

    defp perform_validation(conn, signature, key) do
      with {:ok, body} <- KineticLib.Plug.BodyCaching.fetch_raw_body(conn),
           true <- signatures_equal?(body, key, signature) do
        conn
        |> maybe_assign(@shopify_topic_header, :shopify_topic)
        |> maybe_assign(@shopify_domain_header, :shopify_shop_domain)
      else
        :error ->
          KineticLib.record_error_message(
            "#{__MODULE__} validation misconfiguration: there is no raw body on #{conn.request_path}"
          )

          fail(conn)

        _ ->
          Logger.warning("#{__MODULE__} validation error on #{conn.request_path}")
          fail(conn)
      end
    end

    defp maybe_assign(conn, header, key) do
      case Conn.get_req_header(conn, header) do
        [value | _] -> Conn.assign(conn, key, value)
        _anything_else -> conn
      end
    end

    defp signatures_equal?(body, {nil, key}, signature) when is_binary(key),
      do: signatures_equal?(body, key, signature)

    defp signatures_equal?(body, {old_key, new_key}, signature)
         when is_binary(old_key) and is_binary(new_key),
         do:
           signatures_equal?(body, old_key, signature) ||
             signatures_equal?(body, new_key, signature)

    defp signatures_equal?(body, key, signature) when is_binary(key) do
      calculated_signature =
        :hmac
        |> :crypto.mac(:sha256, key, body)
        |> Base.encode64()

      KineticLib.secure_compare(signature, calculated_signature)
    end

    def fail(conn) do
      conn
      |> Conn.send_resp(:unauthorized, "")
      |> Conn.halt()
    end
  end
end
