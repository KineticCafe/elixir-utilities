defmodule KineticLib.Tesla.SafePathParams do
  @moduledoc """
  Use templated URLs with provided parameters in either Phoenix (`:id`) or
  OpenAPI (`{id}`) format.

  Useful when logging or reporting metric per URL.

  This variant of Tesla.Middleware.PathParams avoids exceptions thrown by
  `String.to_existing_atom/1` as documented in [tesla #566][tesla#566].
  Additionally, it will apply `URI.encode_www_form/2` over the processed value.

  ## Parameter Values

  Parameter values may be `t:struct/0` or must implement the `Enumerable`
  protocol and produce `{key, value}` tuples when enumerated.

  ## Parameter Name Restrictions

  The parameters must be valid path identifiers like those in Plug.Router, with
  one exception: the parameter may begin with an uppercase character.
  A parameter name should match this regular expression:

      \A[_a-zA-Z][_a-zA-Z0-9]*\z

  Parameters that begin with underscores (`_`) or otherwise do not match as
  valid are ignored and left as-is.

  ## Examples

  ```elixir
  defmodule MyClient do
    use Tesla

    plug Tesla.Middleware.BaseUrl, "https://api.example.com"
    plug Tesla.Middleware.Logger # or some monitoring middleware
    plug KineticLib.Tesla.SafePathParams

    def user(id) do
      params = [id: id]
      get("/users/{id}", opts: [path_params: params])
    end

    def posts(id, post_id) do
      params = [id: id, post_id: post_id]
      get("/users/:id/posts/:post_id", opts: [path_params: params])
    end
  end
  ```

  [tesla#566]: https://github.com/elixir-tesla/tesla/issues/566
  """

  @behaviour Tesla.Middleware

  @impl Tesla.Middleware
  def call(env, next, _) do
    url = build_url(env.url, env.opts[:path_params])
    Tesla.run(%{env | url: url}, next)
  end

  defp build_url(url, nil), do: url

  defp build_url(url, %_{} = params), do: build_url(url, Map.from_struct(params))

  defp build_url(url, params) do
    params
    |> Enum.map(fn {name, value} -> {to_string(name), value} end)
    |> Enum.sort_by(fn {name, _} -> String.length(name) end, :desc)
    |> Enum.reduce(url, &replace_parameter/2)
  end

  # Do not replace parameters with nil values.
  defp replace_parameter({_name, nil}, url), do: url
  defp replace_parameter({name, value}, url), do: replace_parameter(to_string(name), value, url)

  defp replace_parameter(<<h, t::binary>>, value, url)
       when h in ?a..?z or h in ?A..?Z do
    case parse_name(t, <<h>>) do
      :error ->
        url

      name ->
        encoded_value =
          value
          |> to_string()
          |> URI.encode_www_form()

        url
        |> String.replace(":#{name}", encoded_value)
        |> String.replace("{#{name}}", encoded_value)
    end
  end

  # Do not replace parameters that do not start with a..z or A..Z.
  defp replace_parameter(_name, _value, url), do: url

  # This is adapted from Plug.Router.Utils.parse_suffix/2. This verifies that
  # the provided parameter *only* contains the characters documented as
  # accepted.
  #
  # https://github.com/elixir-plug/plug/blob/main/lib/plug/router/utils.ex#L255-L260
  defp parse_name(<<h, t::binary>>, acc)
       when h in ?a..?z or h in ?A..?Z or h in ?0..?9 or h == ?_,
       do: parse_name(t, <<acc::binary, h>>)

  defp parse_name(<<>>, acc), do: acc

  defp parse_name(_, _), do: :error
end
