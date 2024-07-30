defmodule KineticLib.ReleaseMetadata do
  @moduledoc """
  Compile release metadata into the application and return it as an optionally
  filtered map.

  This is based on [cartage-rack](https://github.com/KineticCafe/cartage-rack).
  """

  alias KineticLib.ReleaseMetadata.Format
  alias KineticLib.ReleaseMetadata.Git, as: KGit

  def metadata do
    file = metadata_file()

    with true <- File.exists?(file),
         {:ok, body} <- File.read(file),
         {:ok, metadata} <- Jason.decode(body, keys: :atoms!) do
      metadata
    else
      _ -> construct_metadata()
    end
  end

  def current_metadata, do: Format.format(KGit.info())

  defp construct_metadata do
    if(Code.ensure_loaded?(Git), do: current_metadata(), else: static_metadata())
  end

  @static_metadata Format.format(KGit.info())
  defp static_metadata, do: @static_metadata

  defp metadata_file do
    :kinetic_lib
    |> :code.priv_dir()
    |> List.to_string()
    |> Path.join("release-metadata.json")
  end
end
