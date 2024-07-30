defmodule KineticLib.Sentry.Events do
  @moduledoc false

  def before_send(event) do
    if filter_event?(event) do
      false
    else
      update_event(event)
    end
  end

  defp filter_event?(event) do
    already_recorded?(event)
  end

  defp already_recorded?(event) do
    get_in(event.extra, [:logger_metadata, :mfa]) == {KineticLib, :record_error_message, 3}
  end

  defp update_event(event) do
    event
    |> update_fingerprint()
    |> clean_extra_metadata(["__sentry_metadata", "__logger_metadata"])
  end

  defp update_fingerprint(%{exception: [%{type: DBConnection.ConnectionError}]} = event) do
    %{event | fingerprint: ["ecto", "db_connection", "timeout"]}
  end

  defp update_fingerprint(event), do: event

  defp clean_extra_metadata(event, keys) do
    %{event | extra: Map.drop(event.extra, keys)}
  end
end
