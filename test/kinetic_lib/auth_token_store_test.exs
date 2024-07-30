defmodule KineticLib.AuthTokenStoreTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

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

    def clean_credentials(%{caller: caller_pid}) do
      %{caller: caller_pid, status: "[Filtered]"}
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

    def clean_credentials(%{caller: caller_pid}) do
      %{caller: caller_pid, status: "[Filtered]"}
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

    def clean_credentials(%{caller: caller_pid}) do
      %{caller: caller_pid, status: "[Filtered]"}
    end
  end

  describe "AuthTokenStore.request/4" do
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

    test "fails with a bad token" do
      assert {:error, "request failed"} = AuthTokenStore.request(TestTokenProvider, %{})
    end

    test "reports an issue on timeout" do
      log =
        capture_log(fn ->
          assert {:error, :timeout} =
                   AuthTokenStore.request(
                     AuthTokenStore,
                     TimeoutTokenProvider,
                     %{status: :ok, caller: self()},
                     50
                   )
        end)
        |> String.split("\n")
        |> Enum.reject(
          &(&1 == "" ||
              String.starts_with?(&1, "\e") ||
              String.contains?(&1, "duplicate of a previously-captured event"))
        )

      assert Enum.any?(log, &String.contains?(&1, "timeout requesting auth token"))
      assert Enum.any?(log, &String.contains?(&1, "status: \"[Filtered]\""))

      refute_received :request_token
    end
  end
end
