defmodule KineticLib.Sqitch.Status do
  @moduledoc "Return the same as `sqitch status`."

  import Ecto.Query

  defmacro __using__(options) do
    quote do
      @repo unquote(options[:repo])
      @doc "The repo for Sqitch status inquiries."
      def repo, do: @repo

      @project unquote(options[:project])
      @doc "The default project for Sqitch inquiries."
      def project, do: @project

      @prefix unquote(options[:prefix] || "sqitch")
      @doc "The schema prefix for Sqitch inquiries "
      def prefix, do: @prefix

      import KineticLib.Sqitch.Status

      @doc "The status for the default project, or another project if provided."
      def status, do: status(project())

      def status(project) do
        status =
          if repo().config()[:database] == "" do
            %{project: project}
          else
            repo().one(status_query(project), prefix: prefix())
          end

        struct(KineticLib.Sqitch.Status, status)
      end
    end
  end

  @derive {Jason.Encoder,
           only: [:change_id, :change, :script_hash, :project, :planned_at, :planner_name]}
  defstruct [
    :change_id,
    :script_hash,
    :change,
    :project,
    :note,
    :committer_name,
    :committer_email,
    :committed_at,
    :planner_name,
    :planner_email,
    :planned_at,
    :tags
  ]

  @type t :: %__MODULE__{
          change_id: String.t(),
          script_hash: String.t(),
          change: String.t(),
          project: String.t(),
          note: String.t(),
          committer_name: String.t(),
          committer_email: String.t(),
          committed_at: String.t(),
          planner_name: String.t(),
          planner_email: String.t(),
          planned_at: String.t(),
          tags: list(String.t())
        }

  @date_format "YYYY-MM-DD HH24:MI:SS UTC"

  def status_query(project) do
    from c in "changes",
      # left_join: t in ^tags(),
      # The above is replaced by the following 2 lines.
      # It works on Ecto 2.x.x but not on Ecto 3.2.x because of a bug that will only be fixed at Ecto 3.3.x
      # Ref: https://github.com/elixir-ecto/ecto/blob/3423c6363dfd57114faa991ad3672283e6f5341f/CHANGELOG.md
      left_join: t in "tags",
      prefix: "sqitch",
      on: [change_id: c.change_id],
      where: c.project == ^project,
      group_by: [
        c.change_id,
        c.script_hash,
        c.change,
        c.project,
        c.note,
        c.committer_name,
        c.committer_email,
        c.committed_at,
        c.planner_name,
        c.planner_email,
        c.planned_at
      ],
      order_by: [desc: c.committed_at],
      limit: 1,
      select: %{
        change_id: c.change_id,
        script_hash: c.script_hash,
        change: c.change,
        project: c.project,
        note: c.note,
        committer_name: c.committer_name,
        committer_email: c.committer_email,
        committed_at:
          fragment(
            "to_char(? AT TIME ZONE 'UTC', ?)",
            c.committed_at,
            ^@date_format
          ),
        planner_name: c.planner_name,
        planner_email: c.planner_email,
        planned_at:
          fragment(
            "to_char(? AT TIME ZONE 'UTC', ?)",
            c.planned_at,
            ^@date_format
          ),
        tags:
          fragment(
            "ARRAY(SELECT * FROM UNNEST(array_agg(?)) a WHERE a IS NOT NULL)",
            t.tag
          )
      }
  end

  def _changes_query(project) do
    from c in "changes",
      where: c.project == ^project,
      order_by: [desc: c.committed_at],
      select: %{
        change_id: c.change_id,
        script_hash: c.script_hash,
        change: c.change,
        project: c.project,
        note: c.note,
        committer_name: c.committer_name,
        committer_email: c.committer_email,
        committed_at:
          fragment(
            "to_char(? AT TIME ZONE 'UTC', ?)",
            c.committed_at,
            ^@date_format
          ),
        planner_name: c.planner_name,
        planner_email: c.planner_email,
        planned_at:
          fragment(
            "to_char(? AT TIME ZONE 'UTC', ?)",
            c.planned_at,
            ^@date_format
          )
      }
  end

  def _tags_query(project) do
    from t in "tags",
      where: t.project == ^project,
      order_by: [desc: t.committed_at],
      select: %{
        tag_id: t.tag_id,
        tag: t.tag,
        committer_name: t.committer_name,
        committer_email: t.committer_email,
        committed_at:
          fragment(
            "to_char(? AT TIME ZONE 'UTC', ?)",
            t.committed_at,
            ^@date_format
          ),
        planner_name: t.planner_name,
        planner_email: t.planner_email,
        planned_at:
          fragment(
            "to_char(? AT TIME ZONE 'UTC', ?)",
            t.planned_at,
            ^@date_format
          )
      }
  end

  # defp tags, do: from(t in "tags")
end
