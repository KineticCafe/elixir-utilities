defmodule KineticLib.AuthTokenStore.Supervisor do
  @moduledoc """
  A supervisor for `KineticLib.AuthTokenStore.ProviderStore`s.
  """

  use Supervisor

  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  def init(_options) do
    Supervisor.init([], strategy: :one_for_one)
  end
end
