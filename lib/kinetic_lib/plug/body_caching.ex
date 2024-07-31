if Code.loaded?(Plug) do
  defmodule KineticLib.Plug.BodyCaching do
    @enable_key :kinetic_body_caching
    @body_key :kinetic_raw_body

    @moduledoc """
    This module provides all features required to cache a request body.

    In your primary `endpoint.ex`, you would configure the following:

        plug KineticLib.Plug.BodyCaching,
          headers: ["x-shopify-hmac-sha256", "x-twilio-signature"]

        plug Plug.Parsers,
          body_reader: {KineticLib.Plug.BodyCaching, :read_body, []},
          json_decoder: Jason,
          parsers: [:urlencoded, :multipart, :json],
          pass: ["*/*"],
          validate_utf8: true

    Later, when the body is required (such as in a Twilio webhook validator), the
    body would be retrieved with `fetch_raw_body/1` or `get_raw_body/1`.

    See `Plug.Conn.read_body/2` for more details.

    ## Plug

    `KineticLib.Plug.BodyCaching` must be placed before `Plug.Parsers` or any
    other plug that reads the connection body. It *must* be plugged with at least
    one of the `headers` or `matcher` options.

    If both `headers` and `matcher` are specified, a match in `headers` will
    short-circuit the logic and the `matcher` will not be run. If exclusive
    behaviour is required, use a suitably written `matcher`.

    ### Options

    - `:headers`: A list of header names that, if any one is present in the
      request headers, set `conn.assigns.#{@enable_key}` so that the body reader
      can cache the body. Example headers are `x-shopify-hmac-sha256` or
      `x-twilio-signature`.

    - `:matcher`: A `function/1` that accepts the `conn` and returns a boolean
      value if the request body is to be cached. This could be used for matching
      parts of `conn.path_info` or other possible signals.

      This may also be specified as `{module, function, [args...]}` and the
      `conn` will be prepended to the args.

    ## `read_body/2`

    This function is intended to replace `Plug.Conn.read_body/2` in the
    `body_reader` option of `Plug.Parsers`. If `conn.assigns.#{@enable_key}` is
    set, this will then read and cache the body as iolist chunks in
    `conn.assigns.#{@body_key}`.

    ## `fetch_raw_body/1` and `get_raw_body/1`

    These get the raw body from `conn.assigns.#{@body_key}` as a usable binary
    string instead of the cached iolist.
    """

    @behaviour Plug

    alias Plug.Conn

    @doc """
    Fetches the raw body from `conn.assigns.#{@body_key}`, returning `:error`
    or `{:ok, body :: binary()}`.

    Cached bodies that are binary strings or `iodata` lists will be returned as
    a binary string. All other values will return `:error`.
    """
    def fetch_raw_body(%Conn{} = conn) do
      case Map.fetch(conn.assigns, @body_key) do
        :error -> :error
        {:ok, value} when is_binary(value) -> {:ok, value}
        {:ok, value} when is_list(value) -> {:ok, IO.iodata_to_binary(value)}
        _anything_else -> :error
      end
    end

    @doc """
    Gets the raw body from `conn.assigns.#{@body_key}`, returning the body
    binary string or `nil`.

    See `fetch_raw_body/1`.
    """
    def get_raw_body(%Conn{} = conn) do
      case fetch_raw_body(conn) do
        :error -> nil
        {:ok, value} -> value
      end
    end

    @doc """
    This will read the request body via `Plug.Conn.read_body/2` and will store
    it in `conn.assigns.#{@body_key}` if caching is enabled.

    See `enabled?/1`.
    """
    def read_body(conn, opts \\ []) do
      case Conn.read_body(conn, opts) do
        {:ok, body, conn} -> {:ok, body, maybe_store_body_chunk(conn, body)}
        {:more, body, conn} -> {:more, body, maybe_store_body_chunk(conn, body)}
        {:error, reason} -> {:error, reason}
      end
    end

    @doc """
    Returns whether caching is enabled (`conn.assigns.#{@enable_key}` is `true`).
    """
    def enabled?(%Conn{assigns: %{@enable_key => true}}), do: true
    def enabled?(_conn), do: false

    # These functions are public for testing, but should not be used otherwise.
    @doc false
    def __set_caching({conn, true}), do: Conn.assign(conn, @enable_key, true)
    def __set_caching({conn, false}), do: conn

    @type headers :: list(binary())
    @type matcher :: (Conn.t() -> boolean()) | {module(), atom(), list(term())}
    @type option :: {:headers, headers} | {:matcher, matcher}

    @impl Plug
    def init(options) do
      headers = get_headers(options)
      matcher = get_matcher(options)

      if is_nil(headers) && is_nil(matcher) do
        raise ArgumentError,
              "plug #{__MODULE__} requires at least one of `headers` or `matcher` options."
      end

      {headers, matcher}
    end

    @impl Plug
    def call(conn, {headers, matcher}) do
      conn
      |> check_headers(headers)
      |> check_matcher(matcher)
      |> __set_caching()
    end

    defp get_headers(options) do
      case Keyword.fetch(options, :headers) do
        :error ->
          nil

        {:ok, [_ | _] = list} ->
          list

        {:ok, _value} ->
          raise ArgumentError, "option `headers` must be a list with at least one value"
      end
    end

    defp get_matcher(options) do
      case Keyword.fetch(options, :matcher) do
        :error ->
          nil

        {:ok, function} when is_function(function, 1) ->
          function

        {:ok, {m, f, a}} when is_atom(m) and is_atom(f) and is_list(a) ->
          {m, f, a}

        {:ok, _value} ->
          raise ArgumentError,
                "option `matcher` must be either `function/1` or `{module, function, args}`"
      end
    end

    defp check_headers(conn, nil = _headers), do: {conn, false}
    defp check_headers(conn, [] = _headers), do: {conn, false}

    # The `--` list operator binds rightmost first, so this is:
    # headers -- (headers -- request_headers). Using numbers:
    #
    #     [1, 2, 3] -- ([1, 2, 3] -- [2])
    #     [1, 2, 3] -- [1, 3]
    #     [2]
    #
    # See `Kernel.--/2` for more information.
    defp check_headers(conn, headers),
      do: {conn, Enum.any?(headers -- headers -- Enum.map(conn.req_headers, &elem(&1, 0)))}

    defp check_matcher({conn, true}, _matcher), do: {conn, true}
    defp check_matcher({conn, false}, nil = _matcher), do: {conn, false}

    defp check_matcher({conn, false}, {module, function, args}),
      do: {conn, apply(module, function, [conn | args])}

    defp check_matcher({conn, false}, function), do: {conn, function.(conn)}

    defp maybe_store_body_chunk(conn, chunk) do
      if enabled?(conn) do
        store_body_chunk(conn, chunk)
      else
        conn
      end
    end

    defp store_body_chunk(conn, chunk) when is_binary(chunk) do
      chunks = conn.assigns[@body_key] || []
      Conn.assign(conn, @body_key, [chunks | chunk])
    end
  end
end
