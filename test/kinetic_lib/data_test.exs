defmodule KineticLib.DataTest do
  use ExUnit.Case, async: true
  doctest KineticLib.Data, import: true

  alias KineticLib.Data

  defmodule Product do
    defstruct [:code]
  end

  setup_all do
    %{
      data_1: %{
        :name => %{
          "first_name" => "Bob",
          "last_name" => nil
        },
        "id" => "test_id",
        :code => 123,
        "is_guest" => false
      },
      data_2: %{
        :name => %{
          "first_name" => "Sue",
          "last_name" => "Loblaw"
        },
        "id" => "other_id",
        :code => 456,
        "is_guest" => true,
        "email_perm" => false
      }
    }
  end

  describe "dig/2" do
    test "accepts nils objects" do
      assert nil == Data.dig(nil, ~w(a b c))
    end

    test "can use a string key", %{data_1: data} do
      assert "test_id" == Data.dig(data, "id")
    end

    test "can use an atom key", %{data_1: data} do
      assert 123 == Data.dig(data, :code)
    end

    test "can use a list of keys", %{data_1: data} do
      assert "Bob" == Data.dig(data, [:name, "first_name"])
    end

    test "returns nil if key in list not found", %{data_1: data} do
      assert nil == Data.dig(data, [:name, "extras", "title"])
    end
  end

  describe "dig/3" do
    test "accepts nils objects", %{data_1: data_1, data_2: data_2} do
      assert "Bob" == Data.dig(data_1, nil, [:name, "first_name"])
      assert "Sue" == Data.dig(nil, data_2, [:name, "first_name"])
    end

    test "returns newer value if key found", %{data_1: data_1, data_2: data_2} do
      assert "Bob" == Data.dig(data_1, data_2, [:name, "first_name"])
      assert false == Data.dig(data_1, data_2, "is_guest")
      assert true == Data.dig(data_2, data_1, "is_guest")
    end

    test "checks old if new value is nil", %{data_1: data_1, data_2: data_2} do
      assert "Loblaw" == Data.dig(data_1, data_2, [:name, "last_name"])
    end

    test "checks old if key not in new", %{data_1: data_1, data_2: data_2} do
      assert false == Data.dig(data_1, data_2, "email_perm")
    end
  end

  describe "dig/4" do
    test "accepts nils objects", %{data_1: data_1, data_2: data_2} do
      assert "Bob" == Data.dig(data_1, nil, [:name, "first_name"], [:name, "last_name"])
      assert "Sue" == Data.dig(nil, data_2, [:name, "first_name"], [:name, "last_name"])
    end

    test "can return new key1", %{data_1: data_1, data_2: data_2} do
      assert "Sue" == Data.dig(data_2, data_1, [:name, "first_name"], [:name, "last_name"])
      assert false == Data.dig(data_1, data_2, "is_guest", "code")
    end

    test "can return new key2", %{data_1: data_1, data_2: data_2} do
      assert "Bob" == Data.dig(data_1, data_2, [:name, "last_name"], [:name, "first_name"])
      assert false == Data.dig(data_1, data_2, [:name, "last_name"], "is_guest")
    end

    test "can return old key1", %{data_1: data_1, data_2: data_2} do
      assert "Loblaw" == Data.dig(data_1, data_2, [:name, "last_name"], :extra)
      assert false == Data.dig(data_1, data_2, "email_perm", :extra)
    end

    test "can return old key2", %{data_1: data_1, data_2: data_2} do
      assert "Loblaw" == Data.dig(data_1, data_2, :extra, [:name, "last_name"])
      assert false == Data.dig(data_1, data_2, :extra, "email_perm")
    end
  end

  describe "subset?/2" do
    test "success on exact match" do
      map1 = %{code: "A"}
      assert Data.subset?(map1, map1)
    end

    test "success when map1 is subset" do
      assert Data.subset?(%{code: "A"}, %{code: "A", data: %{}})
    end

    test "success when map2 is a struct" do
      assert Data.subset?(%{code: "A"}, %Product{code: "A"})
    end

    test "success when the same struct type" do
      assert Data.subset?(
               %Product{code: "A"},
               %Product{code: "A"}
             )
    end

    test "fails if not matching" do
      refute Data.subset?(%{code: "A"}, %{code: "B"})
    end

    test "fails if map1 is a different struct type" do
      map1 = %Product{code: "A"}
      map2 = Map.from_struct(map1)

      refute Data.subset?(map1, map2)
    end

    test "fails when map2 is a subset" do
      refute Data.subset?(%{code: "A", data: %{}}, %{code: "A"})
    end

    test "raises if not maps or structs" do
      assert_raise(FunctionClauseError, fn -> Data.subset?(nil, %{code: "A"}) end)
      assert_raise(FunctionClauseError, fn -> Data.subset?(%{code: "A"}, []) end)
      assert_raise(FunctionClauseError, fn -> Data.subset?(nil, nil) end)
    end
  end
end
