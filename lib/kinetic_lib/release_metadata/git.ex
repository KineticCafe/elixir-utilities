defmodule KineticLib.ReleaseMetadata.Git do
  @moduledoc "Read current metadata from Git."

  def info do
    %{git: Git.new("."), type: "git"}
    |> git_hashref()
    |> git_url()
    |> Map.drop([:git])
  end

  defp git_hashref(%{git: git} = info) do
    ref =
      git
      |> Git.rev_parse!("HEAD")
      |> String.trim("\n")

    ref =
      case Git.symbolic_ref(git, ~w(--short --quiet HEAD)) do
        {:error, _} -> ref
        {:ok, "master\n"} -> ref
        {:ok, branch} -> "#{String.trim(branch, "\n")} (#{ref})"
      end

    Map.put(info, :hashref, ref)
  end

  defp git_url(%{git: git} = info) do
    url =
      case Git.remote(git, ~w(get-url origin)) do
        {:ok, url} ->
          String.trim(url, "\n")

        {:error, _} ->
          git_fetch_url(git)
      end

    info
    |> Map.put(:url, url)
    |> Map.put(:name, Path.basename(url, ".git"))
  end

  defp git_fetch_url(git) do
    case Git.remote(git, ~w(show -n origin)) do
      {:error, _} ->
        "UNKNOWN"

      {:ok, url} ->
        case Regex.named_captures(~r/\n\s+Fetch URL: (?<fetch>[^\n]+)/, url) do
          %{"fetch" => url} -> url
          _ -> "UNKNOWN"
        end
    end
  end
end
