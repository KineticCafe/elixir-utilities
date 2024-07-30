defmodule KineticLib.Ecto.Changeset.Validations do
  @moduledoc "Additional Ecto.Changeset validations."

  alias KineticLib.Data

  import Ecto.Changeset

  @doc """
  Checks that at least one of the `fields` is present (not `nil` or blank) in
  the `changeset`.
  """
  def validate_required_inclusion(changeset, fields) when is_list(fields) do
    if Enum.any?(fields, &field_present?(changeset, &1)) do
      changeset
    else
      message = "At least one of these fields must be present: " <> "(#{Enum.join(fields, ", ")})"
      Enum.reduce(fields, changeset, &add_error(&2, &1, message))
    end
  end

  @doc "Checks that the fields provided are not changed once set."
  def validate_immutable(changeset, field, opts \\ [])

  def validate_immutable(changeset, fields, opts) when is_list(fields) do
    Enum.reduce(fields, changeset, &validate_immutable(&2, &1, opts))
  end

  def validate_immutable(changeset, field, opts) do
    data_value = Map.get(changeset.data, field)
    change_value = get_change(changeset, field)

    if Data.present?(data_value) && Data.present?(change_value) && data_value != change_value do
      add_error(changeset, field, Keyword.get(opts, :message, "cannot be changed once set"),
        immutable: true
      )
    else
      changeset
    end
  end

  @doc "Checks that the changeset is not changing the catalog."
  def validate_no_catalog_change(changeset) do
    validate_immutable(changeset, :catalog_id, message: "cannot change catalogs once created")
  end

  defp field_present?(changeset, field) do
    changeset
    |> get_field(field)
    |> Data.present?()
  end
end
