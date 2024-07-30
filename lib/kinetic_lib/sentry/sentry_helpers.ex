defmodule KineticLib.SentryHelpers do
  @moduledoc """
  Extra functionality to help with Sentry.

  There are some functions which pass their arguments straight through to
  `Sentry` functions of the same name. This allows:

  - Client apps of this library to **not** include sentry in their `mix.exs`.
  - Client code to ignore whether the Sentry call failed or not without
    requiring `_ = …` to keep `dialyzer` happy.
  """

  @logger_metadata_key Sentry.Context.__logger_metadata_key__()

  @typedoc """
  A Base64 encoded Erlang Term Format string containing the raw Sentry process
  context.

  Suitable for storing in a database field.
  """
  @type context_etf :: binary()

  @doc """
  Gets the unformatted sentry context for a process. Use with
  `replace_raw_process_context/1`.

  > ### WARNING {: .warning}
  >
  > This is based on private implementation details of `Sentry.Context`,
  > so we may need to adjust it when upgrading Sentry.
  """
  def get_raw_process_context do
    case :logger.get_process_metadata() do
      %{@logger_metadata_key => sentry} -> sentry
      %{} -> %{}
      :undefined -> %{}
    end
  end

  @doc """
  Gets the `t:context_etf/0` representation of the process Sentry context. Use
  with `replace_raw_process_context_from_etf/1`.

  > ### WARNING {: .warning}
  >
  > This is based on private implementation details of `Sentry.Context`,
  > so we may need to adjust it when upgrading Sentry.
  """
  def get_raw_process_context_as_etf do
    get_raw_process_context()
    |> :erlang.term_to_binary([:compressed])
    |> Base.encode64()
  end

  @doc """
  Replaces the Sentry context for a process with `new_context`. Use with
  `get_raw_process_context/0`.

  This allows the Sentry context to be copied across process boundaries.

  > ### WARNING {: .warning}
  >
  > This is based on private implementation details of `Sentry.Context`,
  > so we may need to adjust it when upgrading Sentry.
  """
  def replace_raw_process_context(new_context) do
    :logger.update_process_metadata(%{@logger_metadata_key => new_context})
  end

  @doc """
  Replaces the Sentry context for a process with `new_context_etf`, which
  must be `t:context_etf/0`. Use with `get_raw_process_context_as_etf/0`.

  This allows the Sentry context to be copied across process boundaries
  or loaded from a stored database record such as for Oban jobs.

  > ### WARNING {: .warning}
  >
  > This is based on private implementation details of `Sentry.Context`,
  > so we may need to adjust it when upgrading Sentry.
  """
  def replace_raw_process_context_from_etf(new_context_etf) do
    new_context_etf
    |> Base.decode64!()
    |> KineticLib.non_executable_binary_to_term([:safe])
    |> replace_raw_process_context()
  end

  @doc """
  Use Sentry to capture an exception.

  This uses `Sentry.capture_exception/2` to capture an exception. It
  always returns `nil`, and we should never check the result.
  """
  def capture_exception(exception, opts \\ []) do
    _ = Sentry.capture_exception(exception, opts)

    nil
  end

  @doc """
  Use Sentry to capture a message.

  This uses `Sentry.capture_message/2` to capture a message. It
  always returns `nil`, and we should never check the result.
  """
  def capture_message(message, opts \\ []) do
    _ = Sentry.capture_message(message, opts)

    nil
  end

  # Delegate all of Sentry.Context's functions.

  @doc "See `Sentry.Context.add_breadcrumb/1."
  defdelegate add_breadcrumb(arg), to: Sentry.Context
  @doc "See `Sentry.Context.clear_all/0."
  defdelegate clear_all(), to: Sentry.Context
  @doc "See `Sentry.Context.context_keys/0."
  defdelegate context_keys(), to: Sentry.Context
  @doc "See `Sentry.Context.get_all/0."
  defdelegate get_all(), to: Sentry.Context
  @doc "See `Sentry.Context.set_extra_context/1."
  defdelegate set_extra_context(arg), to: Sentry.Context
  @doc "See `Sentry.Context.set_request_context/1."
  defdelegate set_request_context(arg), to: Sentry.Context
  @doc "See `Sentry.Context.set_tags_context/1."
  defdelegate set_tags_context(arg), to: Sentry.Context
  @doc "See `Sentry.Context.set_user_context/1."
  defdelegate set_user_context(arg), to: Sentry.Context
end
