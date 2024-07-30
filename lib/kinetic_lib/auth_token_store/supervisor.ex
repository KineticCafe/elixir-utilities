defmodule KineticLib.AuthTokenStore.Supervisor do
  @moduledoc """
  A supervisor for the server behind `KineticLib.AuthTokenStore`.
  """

  use Supervisor

  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  def init(options) do
    Supervisor.init([{KineticLib.AuthTokenStore, options}], strategy: :one_for_one)
  end
end
