defmodule KineticLib.AuthTokenStore.ProviderStore do
  @moduledoc """
  `AuthTokenStore.ProviderStore` is an authentication token storage server that
  will hold authentication tokens for a specific token authentication provider.

  Tokens are provided by a module that implements the
  `KineticLib.AuthTokenStore.Provider` behaviour.

  See `KineticLib.AuthTokenStore` for more information.
  """

  use GenServer

  alias KineticLib.AuthTokenStore.StoredToken

  defmodule State do
    @moduledoc false

    # The buffer interval is seconds.
    defstruct tokens: %{}, buffer_interval: 30
  end

  @doc """
  Request a token for the given provider and credentials. If the token is
  found in the state and has not yet expired, the existing token will be
  returned. Otherwise, uses the token provider to obtain the credentials.

  Tokens with timeouts will automatically be refreshed with the provider,
  using token refresh capabilities if supported by the provider, or by normal
  token acquisition.
  """
  def request(store \\ __MODULE__, provider, credentials, timeout \\ 5000) do
    timeout =
      case function_exported?(provider, :timeout, 0) && provider.timeout() do
        offset when is_integer(offset) -> timeout + offset
        _ -> timeout
      end

    GenServer.call(store, {:request_token, provider, credentials}, timeout)
  catch
    :exit,
    {:timeout, {GenServer, :call, [^store, {:request_token, provider, credentials}, timeout]}} ->
      KineticLib.record_error_message(
        "#{KineticLib.process_name(store)}: timeout requesting auth token for #{provider}",
        %{credentials: provider.clean_credentials(credentials), timeout: timeout}
      )

      {:error, :timeout}
  end

  @doc """
  Releases (invalidates) a token for the given provider and credentials.
  """
  def release(store \\ __MODULE__, provider, credentials) do
    GenServer.call(store, {:release_token, provider, credentials})
  catch
    :exit,
    {:timeout, {GenServer, :call, [^store, {:release_token, provider, credentials}, timeout]}} ->
      KineticLib.record_error_message(
        "#{KineticLib.process_name(store)}: timeout releasing auth token for #{provider}",
        %{credentials: provider.clean_credentials(credentials), timeout: timeout}
      )

      :ok
  end

  @doc false
  def start_link(options \\ []) do
    name = Keyword.get(options, :name, __MODULE__)

    KineticLib.Logger.add_primary_filter(
      name,
      {:genserver_call_timeout,
       fn
         [^name, {:request_token, provider, credentials}, timeout] ->
           [name, {:request_token, provider, provider.clean_credentials(credentials)}, timeout]

         [^name, {:release_token, provider, credentials}, timeout] ->
           [name, {:request_token, provider, provider.clean_credentials(credentials)}, timeout]

         _anything_else ->
           :ignore
       end}
    )

    GenServer.start_link(
      __MODULE__,
      %State{buffer_interval: Keyword.get(options, :buffer_interval, 30)},
      name: name
    )
  end

  @doc false
  def init(state) do
    {:ok, state}
  end

  @doc false
  def handle_call({:request_token, provider, credentials}, _from, state) do
    case find_token(state, provider, credentials) do
      {:ok, %StoredToken{} = token} ->
        {:reply, {:ok, token}, state}

      _ ->
        case acquire_token(state, provider, credentials) do
          {:ok, %StoredToken{} = token, state} ->
            {:reply, {:ok, token}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @doc false
  def handle_call({:release_token, provider, credentials}, _from, state) do
    {:reply, :ok, %{state | tokens: Map.delete(state.tokens, {provider, credentials})}}
  end

  @doc false
  def handle_info({:refresh_token, token}, state) do
    result =
      if function_exported?(token.provider, :refresh_token, 1) do
        refresh_token(state, token)
      else
        acquire_token(state, token.provider, token.credentials)
      end

    case result do
      {:ok, _token, state} ->
        {:noreply, state}

      {:ok, state} ->
        {:noreply, state}

      _ ->
        {:noreply,
         %{state | tokens: Map.delete(state.tokens, {token.provider, token.credentials})}}
    end
  end

  defp acquire_token(state, provider, credentials) do
    case provider.request_token(credentials) do
      {:ok, %StoredToken{} = token} ->
        token = %{token | provider: provider, timestamp: DateTime.utc_now()}
        schedule_refresh(state, token)
        {:ok, token, add_token(state, token)}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :unknown}
    end
  end

  defp refresh_token(state, %StoredToken{provider: provider} = token) do
    case provider.refresh_token(token) do
      {:ok, %StoredToken{} = token} ->
        token = %{token | provider: provider, timestamp: DateTime.utc_now()}
        schedule_refresh(state, token)
        {:ok, add_token(state, token)}

      {:error, reason} ->
        {:error, reason}

      _ ->
        {:error, :unknown}
    end
  end

  defp schedule_refresh(state, token) do
    if is_number(token.ttl) do
      seconds_elapsed = DateTime.diff(DateTime.utc_now(), token.timestamp)
      seconds_wait = Enum.max([0, token.ttl - seconds_elapsed - state.buffer_interval])
      Process.send_after(self(), {:refresh_token, token}, seconds_wait * 1000)
    end
  end

  defp add_token(state, token) do
    %{state | tokens: Map.put(state.tokens, {token.provider, token.credentials}, token)}
  end

  defp find_token(state, provider, credentials) do
    token = Map.get(state.tokens, {provider, credentials})

    case token do
      nil ->
        {:error, :not_found}

      token ->
        if StoredToken.valid?(token) do
          {:ok, token}
        else
          {:error, :not_valid}
        end
    end
  end
end
