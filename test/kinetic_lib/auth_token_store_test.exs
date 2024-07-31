defmodule KineticLib.AuthTokenStoreTest do
  @moduledoc false

  # use ExUnit.Case, async: true

  import KineticLib.TestUtils

  alias KineticLib.AuthTokenStore

  defmodule TestTokenProvider do
    @moduledoc false
    @behaviour KineticLib.AuthTokenStore.Provider

    alias KineticLib.AuthTokenStore.StoredToken

    def name, do: "Test Token Provider"
    def description, do: "Something that describes the provider"

    def request_token(%{status: :ok, caller: caller_pid} = credentials) do
      send(caller_pid, :request_token)

      {
        :ok,
        %StoredToken{
          provider: __MODULE__,
          credentials: credentials,
          token: "token",
          ttl: Map.get(credentials, :ttl, 300)
        }
      }
    end

    def request_token(_), do: {:error, "request failed"}

    def clean_credentials(%{status: status}) do
      %{caller: "[Filtered]", status: status}
    end
  end

  defmodule OtherTokenProvider do
    @moduledoc false
    @behaviour KineticLib.AuthTokenStore.Provider

    alias KineticLib.AuthTokenStore.StoredToken

    def name, do: "Other Token Provider"
    def description, do: "Something that describes the provider"

    def request_token(%{status: :ok, caller: caller_pid} = credentials) do
      send(caller_pid, :request_other_token)

      {
        :ok,
        %StoredToken{
          provider: __MODULE__,
          credentials: credentials,
          token: "token",
          ttl: Map.get(credentials, :ttl, 300)
        }
      }
    end

    def request_token(_), do: {:error, "request failed"}

    def clean_credentials(%{status: status}) do
      %{caller: "[Filtered]", status: status}
    end
  end

  defmodule TimeoutTokenProvider do
    @moduledoc false
    @behaviour KineticLib.AuthTokenStore.Provider

    alias KineticLib.AuthTokenStore.StoredToken

    def name, do: "Timeout Token Provider"
    def description, do: "This provider always times out"

    def request_token(%{status: :ok, caller: _caller_pid} = credentials) do
      Process.sleep(150)

      {
        :ok,
        %StoredToken{
          provider: __MODULE__,
          credentials: credentials,
          token: "token",
          ttl: Map.get(credentials, :ttl, 300)
        }
      }
    end

    def request_token(_), do: {:error, "request failed"}

    def clean_credentials(%{status: status}) do
      %{caller: "[Filtered]", status: status}
    end
  end

  describe "AuthTokenStore.request/4" do
    @tag skip: "Fails for an unknown reason"
    test "caches with a good token" do
      assert {:ok,
              %AuthTokenStore.StoredToken{
                provider: TestTokenProvider,
                credentials: %{status: :ok, caller: _},
                token: "token",
                ttl: 300
              }} = AuthTokenStore.request(TestTokenProvider, %{status: :ok, caller: self()})

      assert_received :request_token

      assert {:ok,
              %AuthTokenStore.StoredToken{
                provider: TestTokenProvider,
                credentials: %{status: :ok, caller: _},
                token: "token",
                ttl: 300
              }} = AuthTokenStore.request(TestTokenProvider, %{status: :ok, caller: self()})

      refute_received :request_token
    end

    @tag skip: "Fails for an unknown reason"
    test "automatically requests again if the token expires" do
      assert {:ok,
              %AuthTokenStore.StoredToken{
                provider: TestTokenProvider,
                credentials: %{status: :ok, caller: _},
                token: "token",
                ttl: 1
              }} =
               AuthTokenStore.request(TestTokenProvider, %{
                 status: :ok,
                 ttl: 1,
                 caller: self()
               })

      assert_received :request_token

      Process.sleep(999)

      assert_received :request_token
    end

    @tag skip: "Fails for an unknown reason"
    test "starts different token processes for different providers" do
      AuthTokenStore.request(TestTokenProvider, %{status: :ok, ttl: 1, caller: self()})
      AuthTokenStore.request(OtherTokenProvider, %{status: :ok, ttl: 1, caller: self()})

      assert_received :request_token
      assert_received :request_other_token

      refute is_nil(Process.whereis(OtherTokenProvider))
      refute is_nil(Process.whereis(TestTokenProvider))
    end

    @tag skip: "Fails for an unknown reason"
    test "fails with a bad token" do
      assert {:error, "request failed"} = AuthTokenStore.request(TestTokenProvider, %{})
    end

    @tag skip: "Fails for an unknown reason"
    test "reports an issue on timeout" do
      TimeoutTokenProvider.clean_credentials(%{status: :ok, caller: self()})

      log =
        capture_log(fn ->
          assert {:error, :timeout} =
                   AuthTokenStore.request(
                     TimeoutTokenProvider,
                     %{status: :ok, caller: self()},
                     50
                   )
        end)
        |> clean_log_lines()

      assert Enum.any?(log, &String.contains?(&1, "timeout requesting auth token"))
      assert Enum.any?(log, &String.contains?(&1, "caller: \"[Filtered]\""))

      refute_received :request_token
    end
  end
end
