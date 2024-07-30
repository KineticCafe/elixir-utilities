defmodule KineticLib.Ecto.Changeset.ValidationsTest do
  use ExUnit.Case, async: true

  alias Ecto.Changeset
  alias KineticLib.Ecto.Changeset.ValidationsTest.Image

  describe "validate_required_inclusion/2" do
    test "marks all fields if all are missing" do
      changeset = Image.changeset(%Image{}, %{})

      assert %Changeset{valid?: false, errors: errors} = changeset
      assert Keyword.has_key?(errors, :color)
      assert Keyword.has_key?(errors, :url)
    end

    test "detects the value as present if already in the schema" do
      changeset = Image.changeset(%Image{url: "here"}, %{})
      assert %Changeset{valid?: true} = changeset
    end

    test "detects the value as present if in the params" do
      changeset = Image.changeset(%Image{}, %{"url" => "here"})
      assert %Changeset{valid?: true} = changeset
    end

    test "detects an override to invalid" do
      changeset = Image.changeset(%Image{url: "here"}, %{"url" => nil})

      assert %Changeset{valid?: false, errors: errors} = changeset
      assert Keyword.has_key?(errors, :color)
      assert Keyword.has_key?(errors, :url)
    end

    test "detects when an immutable field is being changed" do
      changeset = Image.changeset(%Image{url: "here", immutable: "no"}, %{immutable: "yes"})
      assert %Changeset{valid?: false, errors: errors} = changeset
      assert Keyword.has_key?(errors, :immutable)
    end
  end
end
