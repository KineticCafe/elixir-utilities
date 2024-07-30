defmodule Mix.Tasks.Kinetic.Metadata do
  @moduledoc """
  Print or save the release metadata for this application.
  """

  use Mix.Task

  @shortdoc "Output the kinetic release metadata"

  @switches [save: :boolean]

  def run(argv) do
    {parsed, _args, _invalid} = OptionParser.parse(argv, switches: @switches)

    KineticLib.ReleaseMetadata.current_metadata()
    |> Jason.encode!(pretty: true)
    |> print(parsed)
  end

  defp print(metadata, save: true), do: File.write!("release-metadata.json", metadata)
  defp print(metadata, _), do: IO.puts(metadata)
end
