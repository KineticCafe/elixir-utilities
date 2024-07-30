defmodule KineticLib.Logger do
  @moduledoc """
  Helpers for adding log filters[1] to the logger.

  This module makes it easier to add timeout event filters to prevent sensitive
  data from leaking into the logs and/or Sentry via Sentry.LoggerHandler.

  Any filtering can be done against any field in the [log_event][2] type, but
  this has specific support for `{:report, report}` messages containing timeout
  errors.

  [1]: https://www.erlang.org/doc/apps/kernel/logger_chapter#filters
  [2]: https://www.erlang.org/doc/man/logger#type-log_event
  """

  @typedoc """
  An atom name for a KineticLib.Logger filter function to be applied.

  - `:timeout`: `filter_timeout/2`
  - `:genserver_call_timeout`: `filter_genserver_call_timeout/2`
  """
  @type kinetic_filter_tag :: :timeout | :genserver_call_timeout

  @typedoc """
  A logger filter definition that will be parsed by `add_primary_filter/2`
  based on `t:kinetic_filter_tag/0` and turned into a `t::logger.filter/0`.

  The referenced filter functions are used to match filter specific log events
  and simplify the processing of those log events by passing only the extracted
  data to the provided `(term -> term)` function and reintegrating them into
  the event.

  See `filter_timeout/2` and `filter_genserver_call_timeout/2`.
  """
  @type kinetic_filter :: {kinetic_filter_tag, (term -> term)}

  @doc """
  If a primary filter identified with `key` does not yet exist in the logger
  configuration, add it.

  The `{filter, term}` paramter may be one of the following values:

  - `{&function/2, term}` that is passed to `:logger.add_primary_filter/2`
  - `{:timeout, &timeout_filter/1}` that passes `{&filter_timeout/2,
    &timeout_filter/1}` to `:logger.add_primary_filter/2`
  - `{:genserver_call_timeout, &timeout_filter/1}` that passes
    `{&filter_genserver_call_timeout/2, &timeout_filter/1}` to
    `:logger.add_primary_filter/2`
  """
  @spec add_primary_filter(:logger.filter_id(), :logger.filter() | kinetic_filter()) ::
          :ok | {:error, term()}
  def add_primary_filter(filter_id, {:timeout, filter_arg}) do
    add_primary_filter(filter_id, {&__MODULE__.filter_timeout/2, filter_arg})
  end

  def add_primary_filter(filter_id, {:genserver_call_timeout, filter_arg}) do
    add_primary_filter(filter_id, {&__MODULE__.filter_genserver_call_timeout/2, filter_arg})
  end

  def add_primary_filter(filter_id, {_fun, _filter_arg} = filter) do
    if get_in(:logger.get_config(), [:primary, :filter, filter_id]) == nil do
      :logger.add_primary_filter(filter_id, filter)
    else
      :ok
    end
  end

  @doc """
  If the provided log event contains a report with a `timeout` reason, run the
  provided function against the timeout reason (passed as `{:timeout, reason}`
  and reintegrate the response into the event.

  The specific pattern that is matched is one of:

  - `%{msg: {:report, %{report: %{reason: {{:timeout, reason}, _stacktrace}}}}}`
  - `%{msg: {:report, [report: %{reason: {{:timeout, reason}, _stacktrace}}]}}`

  The function may return `:stop` (do not log this event), `:ignore` (pass this
  event to the next filters), or the modified `timeout` tuple (`{:timeout,
  new_reason}`).
  """
  def filter_timeout(event, timeout_filter) when is_function(timeout_filter, 1) do
    with {:report, report} <- event.msg,
         {{:timeout, _reason} = timeout_reason, stacktrace} <- get_in(report, [:report, :reason]) do
      case timeout_filter.(timeout_reason) do
        :stop ->
          :stop

        :ignore ->
          :ignore

        {:timeout, new_reason} ->
          %{
            event
            | msg:
                {:report,
                 put_in(report, [:report, :reason], {{:timeout, new_reason}, stacktrace})}
          }
      end
    else
      _ -> :ignore
    end
  end

  def filter_timeout(_event, _timeout_filter), do: :ignore

  @doc """
  If the provided log event contains a report with a `timeout` reason caused by
  `GenServer.call/3`, run the provided function against the `args` list of the
  timeout reason and reintegrate the response into the event.

  The specific pattern that is matched is one of:

  - `%{msg: {:report, %{report: %{reason: {{:timeout, {GenServer, :call, args}}, _stacktrace}}}}}`
  - `%{msg: {:report, [report: %{reason: {{:timeout, {GenServer, :call, args}}, _stacktrace}}]}}`

  The function may return `:stop` (do not log this event), `:ignore` (pass this
  event to the next filters), or the modified `args` list.
  """
  def filter_genserver_call_timeout(event, timeout_filter) when is_function(timeout_filter, 1) do
    with {:report, report} <- event.msg,
         {{:timeout, {GenServer, :call, args}}, stacktrace} <- get_in(report, [:report, :reason]) do
      case timeout_filter.(args) do
        :stop ->
          :stop

        :ignore ->
          :ignore

        new_args when is_list(new_args) ->
          %{
            event
            | msg:
                {:report,
                 put_in(
                   report,
                   [:report, :reason],
                   {{:timeout, {GenServer, :call, new_args}}, stacktrace}
                 )}
          }
      end
    else
      _ -> :ignore
    end
  end

  def filter_genserver_call_timeout(_event, _timeout_filter), do: :ignore

  @doc """
  A simple Erlang logger filter that inspects every log event.

  This is extremely noisy and would primarily be used for investigating why
  pattern matching for logger filters would not be working.
  """
  def add_inspector do
    add_primary_filter(
      :kinetic_log_inspector,
      {
        fn event, _ ->
          # credo:disable-for-next-line Credo.Check.Warning.IoInspect
          IO.inspect(event, label: "kinetic_log_inspector")
        end,
        nil
      }
    )
  end
end
