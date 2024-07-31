if Code.loaded?(Plug) && Code.loaded?(Absinthe) do
  defmodule KineticLib.Absinthe.Plug.InitializeContext do
    @moduledoc """
    Set up the initial value of the Absinthe context for any GraphQL pipeline
    from context values found in the Plug context.
    """

    @behaviour Plug

    import Plug.Conn

    def init(opts \\ []), do: opts

    def call(conn, opts \\ []) do
      conn
      |> set_request_id()
      |> set_current_user()
      |> set_user_agent()
      |> set_remote_ip()
    end

    defp set_current_user(conn), do: set_context(conn, :current_user)

    defp set_user_agent(conn), do: set_context(conn, :user_agent)

    defp set_remote_ip(conn), do: set_context(conn, :remote_ip, conn.remote_ip)

    defp set_request_id(conn) do
      if request_id = Keyword.get(Logger.metadata(), :request_id) do
        set_context(conn, :request_id, request_id)
      else
        conn
      end
    end

    defp set_context(conn, key, value \\ nil) do
      absinthe =
        conn.private
        |> Map.get(:absinthe, %{context: %{}})
        |> put_in([:context, key], value || conn.assigns[key])

      put_private(conn, :absinthe, absinthe)
    end
  end
end
