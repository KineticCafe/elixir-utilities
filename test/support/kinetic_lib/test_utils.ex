defmodule KineticLib.TestUtils do
  @moduledoc """
  Utility functions useful across multiple test suites.
  """

  alias ExUnit.CaptureIO
  alias ExUnit.CaptureLog

  @doc """
  Override the log level for the duration of the execution of the function.
  """
  def override_log_level(nil, fun) do
    fun.()
  end

  def override_log_level(level, fun) do
    current_level = Logger.level()

    try do
      Logger.configure(level: level)
      fun.()
    after
      Logger.configure(level: current_level)
    end
  end

  @doc """
  This is a wrapper for `ExUnit.CaptureLog.capture_log/2` which automatically
  overrides the log level when the `level` option key is provided.
  """
  def capture_log(options \\ [], fun) do
    override_log_level(Keyword.get(options, :level), fn ->
      CaptureLog.capture_log(options, fun)
    end)
  end

  @doc """
  This is a wrapper for `ExUnit.CaptureLog.with_log/2` which automatically
  overrides the log level when the `level` option key is provided.
  """
  def with_log(options \\ [], fun) do
    override_log_level(Keyword.get(options, :level), fn ->
      CaptureLog.with_log(options, fun)
    end)
  end

  @doc """
  A wrapper around `ExUnit.CaptureLog.with_log/2` that discards the captured
  log and returns the result.
  """
  def silence_log(options \\ [], fun) do
    {result, _} = CaptureLog.with_log(options, fun)
    result
  end

  defdelegate capture_io(fun), to: CaptureIO
  defdelegate capture_io(input_or_options, fun), to: CaptureIO
  defdelegate capture_io(device_or_pid, input_or_options, fun), to: CaptureIO

  defdelegate with_io(fun), to: CaptureIO
  defdelegate with_io(input_or_options, fun), to: CaptureIO
  defdelegate with_io(device_or_pid, input_or_options, fun), to: CaptureIO

  @doc """
  A wrapper around `ExUnit.CaptureIO.with_io/1` that discards the captured
  output.
  """
  def silence_io(fun) do
    {result, _} = CaptureIO.with_io(fun)
    result
  end

  @doc """
  A wrapper around `ExUnit.CaptureIO.with_io/2` that discards the captured
  output.
  """
  def silence_io(input_or_options, fun) do
    {result, _} = CaptureIO.with_io(input_or_options, fun)
    result
  end

  @doc """
  A wrapper around `ExUnit.CaptureIO.with_io/3` that discards the captured
  output.
  """
  def silence_io(device_or_pid, input_or_options, fun) do
    {result, _} = CaptureIO.with_io(device_or_pid, input_or_options, fun)
    result
  end

  @doc """
  An opinionated wrapper around `silence_io/2` that silences stderr.
  """
  def silence_stderr(fun), do: silence_io(:stderr, fun)

  @doc """
  An opinionated wrapper around `silence_io/3` that silences stderr.
  """
  def silence_stderr(options, fun), do: silence_io(:stderr, options, fun)

  @doc """
  Cleans log lines captured with `capture_log/2`.

  This will:

  1. Split the captured log at newlines.
  2. Attempt to remove ANSI control sequences.
  3. Remove blank lins.
  """
  def clean_log_lines(captured_log) do
    captured_log
    |> String.split("\n")
    |> Enum.map(&Regex.replace(~r/\e\[[0-9;?]*[a-zA-Z]/, &1, ""))
    |> Enum.reject(fn line ->
      match?("", line) ||
        String.starts_with?(line, "\e") ||
        String.contains?(line, "duplicate of a previously-captured event")
    end)
  end
end
