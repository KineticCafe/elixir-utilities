defmodule KineticLib.Result.UnwrapError do
  @moduledoc """
  An exception raised when unwrapping a result.
  """

  defexception [:term, :message]

  @impl true
  def message(%{message: nil} = exception), do: build_message(exception.term)
  def message(%{message: message}), do: message

  defp build_message({:error, message}) when is_binary(message), do: message
  defp build_message(term), do: "term #{inspect(term)} is not an {:ok, value} tuple"
end

defmodule KineticLib.Result.ErrorUnwrapError do
  @moduledoc """
  An exception raised when unwrapping an error.
  """

  defexception [:term, :message]

  @impl true
  def message(%{message: nil} = exception),
    do: "term #{inspect(exception.term)} is not an {:error, value} tuple"

  def message(%{message: message}), do: message
end
