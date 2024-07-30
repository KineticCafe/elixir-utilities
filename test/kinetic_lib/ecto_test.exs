defmodule KineticLib.EctoTest do
  @moduledoc false

  use ExUnit.Case

  alias __MODULE__.Bar
  alias __MODULE__.Foo
  alias __MODULE__.MockRepo

  describe "upsert_all/4" do
    test "uses default options" do
      entries = sample_entries()
      result = KineticLib.Ecto.upsert_all(MockRepo, Foo, entries)

      assert {Foo, ^entries, opts} = result

      assert [:active, :updated_at] = get_replace_fields(opts),
             "Should not replace primary keys and `inserted_at` because default is `[:insert_only]`"

      assert false == opts[:returning]
    end

    test "can specify options" do
      entries = sample_entries()
      conflict_target = [:code, :updated_at]

      result =
        KineticLib.Ecto.upsert_all(MockRepo, Foo, entries,
          conflict_target: conflict_target,
          replace_fields_except: [:active],
          returning: true
        )

      assert {Foo, ^entries, opts} = result

      assert conflict_target == opts[:conflict_target]

      assert [:code, :inserted_at, :updated_at] = get_replace_fields(opts),
             "Should replace everything except `:active`"

      assert true = opts[:returning]
    end

    test "does not raise if `conflict_target/0` function is defined on the schema module" do
      assert {_, _, opts} = KineticLib.Ecto.upsert_all(MockRepo, Foo, sample_entries())
      assert [:code] = opts[:conflict_target]
    end

    test "raises if `conflict_target` not passed and not implemented" do
      assert_raise(
        RuntimeError,
        ~r/conflict_target/,
        fn -> KineticLib.Ecto.upsert_all(MockRepo, Bar, sample_entries()) end
      )
    end
  end

  defp sample_entries do
    [
      %{
        code: "A",
        active: true,
        inserted_at: ~U[1900-01-01 01:01:01.000000Z]
      }
    ]
  end

  defp get_replace_fields(opts) do
    {:replace, fields} = opts[:on_conflict]
    Enum.sort(fields)
  end

  defmodule MockRepo do
    def insert_all(schema, entries, opts \\ []) do
      {schema, entries, opts}
    end
  end

  defmodule Foo do
    use Ecto.Schema
    @primary_key {:code, :string, []}

    schema "foo" do
      field(:active, :boolean)

      timestamps(type: :utc_datetime_usec)
    end

    def conflict_target, do: [:code]
  end

  defmodule Bar do
    use Ecto.Schema
    @primary_key {:code, :string, []}

    schema "bar" do
      field(:active, :boolean)

      timestamps(type: :utc_datetime_usec)
    end
  end
end
