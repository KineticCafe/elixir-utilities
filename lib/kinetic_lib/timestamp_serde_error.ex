defmodule KineticLib.TimestampSerdeError do
  @moduledoc "Errors during parsing or formatting timestamps."

  defexception [:message]

  @impl true
  def exception(value), do: %__MODULE__{message: value}
end
