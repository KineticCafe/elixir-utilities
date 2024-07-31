defmodule KineticLib.ScytaleTest do
  use ExUnit.Case, async: true

  import KineticLib.Scytale

  @key "abc123"

  describe "encrypt and decrypt" do
    test "token with string" do
      token = encrypt(@key, "secret", 1)
      assert decrypt(@key, "secret", token) == {:ok, 1}
    end

    test "fails on missing token" do
      assert decrypt(@key, "secret", nil) == {:error, :missing}
    end

    test "fails on invalid token" do
      token = encrypt(@key, "secret", 1)

      assert decrypt(@key, "secret", "garbage") ==
               {:error, :invalid}

      assert decrypt(@key, "not_secret", token) ==
               {:error, :invalid}
    end

    test "treats levels differently" do
      token = encrypt(@key, {"personal", "secret"}, 1)

      assert decrypt(@key, {"personal", "secret"}, token) == {:ok, 1}
      assert decrypt(@key, {:medical, "secret"}, token) == {:error, :invalid}
    end

    test "supports max age in seconds" do
      token = encrypt(@key, "secret", 1)
      assert decrypt(@key, "secret", token, max_age: 1000) == {:ok, 1}
      assert decrypt(@key, "secret", token, max_age: -1000) == {:error, :expired}
      assert decrypt(@key, "secret", token, max_age: 100) == {:ok, 1}
      assert decrypt(@key, "secret", token, max_age: -100) == {:error, :expired}

      token = encrypt(@key, "secret", 1)
      assert decrypt(@key, "secret", token, max_age: 0.1) == {:ok, 1}
      Process.sleep(150)
      assert decrypt(@key, "secret", token, max_age: 0.1) == {:error, :expired}
    end

    test "supports max age in seconds on encryption" do
      token = encrypt(@key, "secret", 1, max_age: 1000)
      assert decrypt(@key, "secret", token) == {:ok, 1}

      token = encrypt(@key, "secret", 1, max_age: -1000)
      assert decrypt(@key, "secret", token) == {:error, :expired}
      assert decrypt(@key, "secret", token, max_age: 1000) == {:ok, 1}

      token = encrypt(@key, "secret", 1, max_age: 0.1)
      Process.sleep(150)
      assert decrypt(@key, "secret", token) == {:error, :expired}
    end

    test "supports :infinity for max age" do
      token = encrypt(@key, "secret", 1)
      assert decrypt(@key, "secret", token, max_age: :infinity) == {:ok, 1}
    end

    test "supports signed_at in seconds" do
      seconds_in_day = 24 * 60 * 60
      day_ago_seconds = System.os_time(:second) - seconds_in_day
      token = encrypt(@key, "secret", 1, signed_at: day_ago_seconds)
      assert decrypt(@key, "secret", token) == {:ok, 1}
      assert decrypt(@key, "secret", token, max_age: seconds_in_day + 1) == {:ok, 1}

      assert decrypt(@key, "secret", token, max_age: seconds_in_day - 1) ==
               {:error, :expired}
    end

    test "passes key_iterations options to key generator" do
      signed1 = encrypt(@key, "secret", 1, signed_at: 0, key_iterations: 1)
      signed2 = encrypt(@key, "secret", 1, signed_at: 0, key_iterations: 2)
      assert signed1 != signed2
    end

    test "passes key_digest options to key generator" do
      signed1 = encrypt(@key, "secret", 1, signed_at: 0, key_digest: :sha256)
      signed2 = encrypt(@key, "secret", 1, signed_at: 0, key_digest: :sha512)
      assert signed1 != signed2
    end
  end
end
