defmodule KineticLib.AuthTokenStore do
  # This is the first project to be created to share our token store implementation.

  @moduledoc """
  The AuthTokenStore is an authentication token storage server facade that will
  hold authentication tokens for external services so that requests can be made
  to those services without requiring a new authentication token request, until
  they expire.

  Tokens are provided by a module that implements the
  `KineticLib.AuthTokenStore.Provider` behaviour.

  Inspired by the token store implementation in [Goth][1].

  [1]: https://github.com/peburrows/goth/blob/master/lib/goth/token_store.ex
  """

  alias KineticLib.AuthTokenStore.ProviderStore
  alias KineticLib.AuthTokenStore.Supervisor, as: AuthSupervisor

  @doc """
  Request a token for the given provider and credentials. If the token is
  found in the state and has not yet expired, the existing token will be
  returned. Otherwise, uses the token provider to obtain the credentials.

  Tokens with timeouts will automatically be refreshed with the provider,
  using token refresh capabilities if supported by the provider, or by normal
  token acquisition.
  """
  def request(provider, credentials, timeout \\ 5000) do
    case provider_store(provider) do
      {:ok, store} -> ProviderStore.request(store, provider, credentials, timeout)
      error -> error
    end
  end

  @doc """
  Releases (invalidates) a token for the given provider and credentials.
  """
  def release(provider, credentials) do
    case provider_store(provider) do
      {:ok, store} -> ProviderStore.release(store, provider, credentials)
      error -> error
    end
  end

  defp provider_store(provider) do
    case Process.whereis(provider) do
      nil ->
        spec =
          [name: provider]
          |> ProviderStore.child_spec()
          |> Supervisor.child_spec(id: provider)

        case Supervisor.start_child(AuthSupervisor, spec) do
          {:ok, provider_store} -> {:ok, provider_store}
          {:ok, provider_store, _info} -> {:ok, provider_store}
          {:error, {:already_started, provider_store}} -> {:ok, provider_store}
          {:error, reason} -> {:error, reason}
        end

      provider_store ->
        {:ok, provider_store}
    end
  end
end
