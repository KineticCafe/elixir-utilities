defmodule KineticLib.ReleaseMetadata.Format do
  @moduledoc "Format information into the metadata format."

  @type input :: %{
          name: String.t(),
          hashref: String.t(),
          type: String.t(),
          url: String.t()
        }

  @type t :: %{
          package: %{
            name: String.t(),
            hashref: String.t(),
            timestamp: String.t(),
            repo: %{
              type: String.t(),
              url: String.t()
            },
            elixir: %{
              version: String.t(),
              otp_release: String.t(),
              source_path: String.t()
            }
          }
        }

  def format(%{} = info) do
    %{
      package: %{
        name: info.name,
        hashref: info.hashref,
        timestamp: timestamp(),
        repo: %{
          type: info.type,
          url: info.url
        },
        elixir: %{
          version: System.version(),
          otp_release: System.otp_release(),
          source_path: File.cwd!()
        }
      }
    }
  end

  defp timestamp do
    System.get_env("RELEASE_TIMESTAMP") ||
      Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")
  end
end
