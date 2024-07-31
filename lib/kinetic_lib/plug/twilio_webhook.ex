if Code.loaded?(Plug) do
  defmodule KineticLib.Plug.TwilioWebhook do
    @twilio_header "x-twilio-signature"
    @twilio_region_header "x-home-region"
    @twilio_idempotency_header "i-twilio-idempotency-token"

    @moduledoc """
    Validates that a request from Twilio was properly sent by Twilio.

    This plug must be used in conjunction with `KineticLib.Plug.BodyCaching` in
    order to have access to the raw body for validation.

    This webhook must be configured with a finder function that returns
    a `t:KineticLib.Twilio.RequestValidator.auth_token/0` value.

    Regardless of how it is plugged into your pipelines, it will only run if
    `#{@twilio_header}` is present.

    Successful validation will add the first found values from
    `#{@twilio_region_header}` and `#{@twilio_idempotency_header}` to
    `conn.assigns.twilio_region` and `conn.assigns.twilio_idempotency_token`,
    respectively.

    ## Options

    - `:auth_token`: A `function/1` accepting `conn` and returning the Twilio
      authentication. May be specified as `{module, function, args}`.

          plug KineticWeb.Plugs.TwilioWebhook, finder: {MyCas, :twilio_auth_token, []}
          # or
          plug KineticWeb.Plugs.TwilioWebhook, finder: &MyCas.twilio_auth_token/1
    """

    alias KineticLib.Twilio.RequestValidator
    alias Plug.Conn

    require Logger

    @behaviour Plug

    @type finder ::
            (Conn.t() -> RequestValidator.auth_token()) | {module(), atom(), list(term())}
    @type option :: {:finder, finder}

    @impl true
    def init(options) do
      case Keyword.fetch(options, :finder) do
        :error ->
          raise "`finder` must be specified"

        {:ok, {m, f, a}} when is_atom(m) and is_atom(f) and is_list(a) ->
          {m, f, a}

        {:ok, function} when is_function(function, 1) ->
          function

        _anything_else ->
          raise "`finder` option must be `{module, function, args}` or `function/1`"
      end
    end

    @impl true
    def call(conn, finder) do
      case Conn.get_req_header(conn, @twilio_header) do
        [signature | _] ->
          perform_validation(
            conn,
            signature,
            find_twilio_auth(finder, conn),
            Conn.request_url(conn),
            form_urlencoded?(conn)
          )

        _ ->
          conn
      end
    end

    defp find_twilio_auth(finder, conn) when is_function(finder, 1), do: finder.(conn)

    defp find_twilio_auth({module, function, args}, conn),
      do: apply(module, function, [conn | args])

    defp perform_validation(conn, signature, twilio_auth, request_url, true = _is_form_urlencoded) do
      if RequestValidator.valid?(signature, twilio_auth, request_url, conn.body_params) do
        add_twilio_context(conn)
      else
        fail(conn, "#{__MODULE__} validation error on #{conn.request_path} (params)")
      end
    end

    defp perform_validation(
           conn,
           signature,
           twilio_auth,
           request_url,
           false = _is_form_urlencoded
         ) do
      case KineticLib.Plug.BodyCaching.fetch_raw_body(conn) do
        {:ok, body} ->
          if RequestValidator.valid?(signature, twilio_auth, request_url, body) do
            add_twilio_context(conn)
          else
            fail(conn, "#{__MODULE__} validation error on #{conn.request_path} (body)")
          end

        :error ->
          KineticLib.record_error_message(
            "#{__MODULE__} validation misconfiguration: there is no raw body on #{conn.request_path}"
          )

          fail(conn)
      end
    end

    defp add_twilio_context(conn) do
      conn
      |> maybe_assign(@twilio_region_header, :twilio_region)
      |> maybe_assign(@twilio_idempotency_header, :twilio_idempotency_token)
    end

    defp maybe_assign(conn, header, key) do
      case Conn.get_req_header(conn, header) do
        [value | _] -> Conn.assign(conn, key, value)
        _anything_else -> conn
      end
    end

    defp fail(conn, message) do
      Logger.warning(message)
      fail(conn)
    end

    defp fail(conn) do
      conn
      |> Conn.send_resp(:unauthorized, "")
      |> Conn.halt()
    end

    defp form_urlencoded?(conn) do
      case Conn.get_req_header(conn, "content-type") do
        [value | _] -> String.starts_with?(value, "application/x-www-form-urlencoded")
        _anything_else -> false
      end
    end
  end
end
