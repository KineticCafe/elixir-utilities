defmodule KineticLib.Ecto.Changeset.ValidationsTest.Image do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  import KineticLib.Ecto.Changeset.Validations

  @derive {Jason.Encoder, only: ~w(url color immutable)a}
  embedded_schema do
    field(:url)
    field(:color)
    field(:immutable)
  end

  def changeset(image, params) do
    image
    |> cast(params, [:url, :color, :immutable])
    |> validate_required_inclusion([:url, :color])
    |> validate_immutable(:immutable)
  end
end
