defmodule KineticLib do
  @moduledoc """
  Utility functions not yet sorted to other locations.
  """

  require Logger

  @type logger_function :: (-> String.t() | {String.t(), any()})

  @log_delimiter if Mix.env() == :dev, do: "\n", else: "  "

  @typedoc """
  A Base64 encoded Erlang Term Format string containing the raw Sentry process
  context.

  Suitable for storing in a database field.
  """
  @type context_etf :: binary()

  @doc """
  Returns the current `Logger.metadata/0` output as a `t:context_etf/0`. Use
  with `logger_metadata_from_etf/1`.
  """
  def logger_metadata_as_etf do
    Logger.metadata()
    |> :erlang.term_to_binary([:compressed])
    |> Base.encode64()
  end

  @doc """
  Decodes `new_metadata` (which must be `t:context_etf/0`) and calls
  `Logger.metadata/1`. Use with `logger_metadata_as_etf/0`.
  """
  def logger_metadata_from_etf(new_metadata) do
    new_metadata
    |> Base.decode64!()
    |> non_executable_binary_to_term([:safe])
    |> Logger.metadata()
  end

  @doc """
  Returns the current stacktrace, dropping `current_stacktrace/0` and `Process.info/2`.
  """
  def current_stacktrace do
    {:current_stacktrace, [_, _ | stacktrace]} = Process.info(self(), :current_stacktrace)
    stacktrace
  end

  @doc """
  Captures the Sentry context of the current process, and executes the supplied
  function in a new process with the captured Sentry context.

  This function should only be used when there is no better option such as
  a Task, Agent, GenServer, or Oban task.
  """
  if Mix.env() == :test do
    # This stubbed out version is needed because the way we use database
    # sandboxing at the moment (2023-11-07) means that we'll get
    # DBConnection.OwnershipError exceptions raised if the spawned
    # function makes a database call.
    def spawn_with_sentry_context(function) when is_function(function, 0) do
      function.()
    end
  else
    def spawn_with_sentry_context(function) when is_function(function, 0) do
      alias KineticLib.SentryHelpers

      sentry_context = SentryHelpers.get_raw_process_context()

      spawn(fn ->
        SentryHelpers.replace_raw_process_context(sentry_context)
        function.()
      end)
    end
  end

  @doc """
  Logs the `message` as an error and capture it to Sentry.

  ## Arguments
    * `message` - String to log, or 0-arity function that will result in it
    * `extra` - map of additional info to capture. Will also be logged. Search for
      `SentryHelpers.set_` to see what we already capture with our plugs.

  ## Options
    * `:stacktrace` - Use the value `__STACKTRACE__` when calling from a `rescue`
      block to have a stacktrace from the location of the raised exception instead
      of the from the `rescue`.
      Default is for the stacktrace to start at the caller of this function.

  ## Message structure

  The message should contain:

  1. Where the error happened, for example the function name.
  2. What the error is.
  3. Any supporting detail.
  """
  def record_error_message(message, extra \\ %{}, opts \\ [])

  def record_error_message(fun, extra, opts) when is_function(fun, 0) do
    case fun.() do
      {message, fun_extra} -> record_error_message(message, fun_extra, opts)
      message -> record_error_message(message, extra, opts)
    end
  end

  def record_error_message(message, extra, opts) when is_list(extra) do
    record_error_message(message, Enum.into(extra, %{}), opts)
  end

  def record_error_message(message, extra, opts) do
    opts =
      [extra: extra, result: :none]
      |> Keyword.merge(opts)
      |> add_stacktrace_if_none()

    Logger.error(fn ->
      case Sentry.capture_message(message, opts) do
        {:error, _} ->
          # likely a JSON parsing error on `extra`
          opts = Keyword.update!(opts, :extra, &%{"fallback_parsing" => inspect(&1)})
          _ = Sentry.capture_message(message, opts)
          :ok

        _ ->
          :ok
      end

      if extra == %{} do
        message
      else
        {
          "#{message}#{@log_delimiter}  (metadata):#{@log_delimiter}#{inspect(extra)}",
          extra
        }
      end
    end)

    :ok
  end

  @doc """
  A boundary-enforced wrapper to `Plug.Crypto.secure_compare/2`.
  """
  defdelegate secure_compare(left, right), to: Plug.Crypto

  @doc """
  A boundary-enforced wrapper to `Plug.Crypto.non_executable_binary_to_term/2`.
  """
  defdelegate non_executable_binary_to_term(bin, opts \\ []), to: Plug.Crypto

  @doc """
  Returns true if the provided `module` implements the required callbacks from
  `behaviour`.
  """
  def implements_behaviour?(module, behaviour) do
    required_callbacks =
      behaviour.behaviour_info(:callbacks) -- behaviour.behaviour_info(:optional_callbacks)

    Enum.all?(required_callbacks, &callback_implemented?(&1, module))
  end

  @doc """
  Returns a displayable name for the provided process PID or registered name atom.

  When the provided value is a `t:pid/0`, this attempts to look up a registered
  name for the PID; otherwise, it will be formatted as `#PID<x,y,z>`.

  If the value is neither a `t:pid/0` nor a registered process name, an
  exception will be thrown.

  ### Examples

    iex> pid = spawn(fn -> Process.sleep(5000) end)
    iex> spid = inspect(pid)
    iex> process_name(pid) == spid
    true

    iex> pid = spawn(fn -> Process.sleep(5000) end)
    iex> Process.register(pid, :foo)
    iex> process_name(pid)
    "foo"
    iex> Process.unregister(:foo)

    iex> Process.register(spawn(fn -> Process.sleep(5000) end), :foo)
    iex> process_name(:foo)
    "foo"
    iex> Process.unregister(:foo)

    iex> process_name(hd(Port.list()))
    ** (ArgumentError) expected a PID or a registered process name, got #Port<0.0>

    iex> process_name(:foo)
    ** (ArgumentError) expected a PID or a registered process name, got :foo

    iex> process_name(7)
    ** (ArgumentError) expected a PID or a registered process name, got 7
  """
  def process_name(pid) when is_pid(pid) do
    case Process.info(pid, :registered_name) do
      {:registered_name, name} when is_atom(name) -> Atom.to_string(name)
      _anything_else -> inspect(pid)
    end
  end

  def process_name(name) when is_atom(name) do
    case Process.whereis(name) do
      pid when is_pid(pid) -> Atom.to_string(name)
      _anything_else -> bad_process_name(name)
    end
  end

  def process_name(name), do: bad_process_name(name)

  defp bad_process_name(name) do
    raise ArgumentError, "expected a PID or a registered process name, got #{inspect(name)}"
  end

  defp callback_implemented?({fun, arity}, module), do: function_exported?(module, fun, arity)

  defp add_stacktrace_if_none(opts) do
    if Keyword.has_key?(opts, :stacktrace) do
      opts
    else
      # Ignore this function and the one that calls it
      [_, _ | stacktrace] = current_stacktrace()
      Keyword.put(opts, :stacktrace, stacktrace)
    end
  end
end
