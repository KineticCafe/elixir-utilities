defmodule KineticLib.Sentry.Filter do
  @moduledoc """
  Sentry parameter and header filtering specific to AppIdentity applications
  implemented for Kinetic.
  """

  @doc """
  Scrubs the body parameters of the Sentry event.

  Currently defers to `Sentry.PlugContext.default_body_scrubber/1`, which uses
  `Sentry.PlugContext.scrub_map/3` to scrub any nested keys named `password`,
  `passwd`, or `secret`, and any values that look like a possible credit card
  (13–16 digits, spaces, or dashes).
  """
  def scrub_params(conn) do
    Sentry.PlugContext.default_body_scrubber(conn)
  end

  @doc """
  Scrubs the headers of the Sentry event.

  After delegating to `Sentry.PlugContext.default_header_scrubber/1` for an
  initial pass, we drop any `kcs-application`, `kcs-service`,
  `kcp-application`, or `kcp-service` headers that are found.

  If we can discover resolved Kinetic applications (in `conn.private.kinetic`),
  we will add `kcs-application` / `kcs-service` headers with the application
  `code`.
  """
  def scrub_headers(conn) do
    conn
    |> Sentry.PlugContext.default_header_scrubber()
    |> scrub_kinetic_application_headers()
    |> add_kinetic_applications(conn)
  end

  defp scrub_kinetic_application_headers(headers) do
    Map.drop(headers, ["kcs-application", "kcs-service", "kcp-application", "kcp-service"])
  end

  defp add_kinetic_applications(headers, conn) do
    discovered_applications =
      [
        {"kcs-application", kinetic_application(conn, :application)},
        {"kcs-service", kinetic_application(conn, :service)}
      ]
      |> Enum.reject(&match?({_, nil}, &1))
      |> Enum.into(%{})

    Map.merge(headers, discovered_applications)
  end

  defp kinetic_application(conn, type) do
    case get_in(conn.private, [:kinetic, type]) do
      nil -> nil
      {:ok, %{code: code}} -> code
      %{code: code} -> code
      _ -> "unknown application"
    end
  end
end
