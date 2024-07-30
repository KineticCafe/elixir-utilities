defmodule KineticLib.Timestamp.Serde do
  @moduledoc """
  Timestamp `ser`ialization and `de`serialization functions. Common parsers and
  formatters for `t:Date.t/0`, `t:DateTime.t/0`, and `t:NaiveDateTime.t/0` used
  in the Kinetic Platform.

  This module is called `Serde` after the [serde][serde] crate in Rust, even
  though the hardware terminology is [`SerDes`][serdes]. Aside from being
  easier to type `Serde` than `SerDes`, this is a good working name until we
  come up with a better name.

  ## Parsers (Deserializers)

  The parsers are wrappers around:

  - `Date.from_iso8601/2`
  - `DateTime.from_iso8601/{2,3}`
  - `NaiveDateTime.from_iso8601/2`
  - `Datix.Date.parse/3`
  - `Datix.DateTime.parse/3`
  - `Datix.NaiveDateTime.parse/3`

  ## Formatters (Serializers)

  The formatters are wrappers around:

  - `Date.to_iso8601/2`
  - `DateTime.to_iso8601/2`
  - `NaiveDateTime.to_iso8601/2`
  - `Calendar.strftime/3`

  [serde]: https://crates.io/crates/serde
  [serdes]: https://en.wikipedia.org/wiki/SerDes
  """

  alias KineticLib.TimestampSerdeError

  @typedoc """
  A format based on the formats defined for strftime(3). See
  `Calendar.strftime/3` for the subset of format specifiers supported in
  Elixir.
  """
  @type strftime_format :: String.t()

  @typedoc """
  A format used by `Datix.parse/3`. In most cases, we use `t:Datix.compiled/0`,
  which is an opaque type based on `t:strftime_format/0`.
  """
  @type strptime_format :: strftime_format | Datix.compiled()

  @typedoc """
  An alias for POSIX standard timestamps in the `C` or `en_US` locales (`Tue
  Jul 4 17:27:32 EDT 2023`).
  """
  @type posix_format :: :posix
  @posix_strftime_format "%a %b %d %H:%M:%S %Z %Y"
  @posix_strptime_format Datix.compile!(@posix_strftime_format)

  @typedoc """
  An alias for RFC 2822 standard timestamps typically found in email timestamp
  fields (`Tue, 4 Jul 2023 17:27:32 +0000`).

  > This format was originally defined in RFC 1123 as a delta description over
  > RFC 822, but the first RFC EBNF definition for this format is in RFC 2822.
  > It is replicated in RFC 5322. Timex calls this format `{RFC1123}`; we are
  > using the later RFC as the name.
  """
  @type rfc2822_format :: :rfc2822
  @rfc2822_strftime_format "%a, %d %b %Y %H:%M:%S %z"
  @rfc2822_strptime_format Datix.compile!(@rfc2822_strftime_format)

  @typedoc """
  An alias for RFC 2822 standard timestamps used for email timestamp fields
  where the timestamp is always `Z` (`Tue, 4 Jul 2023 17:27:32Z`).

  > This format uses the obsolete but still common `Z` timestamp. No other
  > timestamp format is supported. Timex calls this format `{RFC1123z}`.

  See `t:rfc2822_format/0`.
  """
  @type rfc2822z_format :: :rfc2822z
  @rfc2822z_strftime_format "%a, %d %b %Y %H:%M:%SZ"
  @rfc2822z_strptime_format Datix.compile!(@rfc2822z_strftime_format)

  @typedoc """
  An alias for the ISO8601 extended format (`2023-07-04T17:27:32Z` or
  `2023-07-04T17:27:32+04:00` with optional microsecond or millisecond
  precision).

  > Either `t:iso8601_format/0` or `t:iso8601z_format/0` may be used
  > for parsing with equivalent results.
  >
  > When formatting `t:DateTime.t/0` values, this alias will use `Z` if the
  > time zone is `Etc/UTC`, but will otherwise write the time zone offset.
  > If strict `Z` formatting is required, the caller should either *shift* the
  > value to be in `Etc/UTC` time zone or use `t:iso8601z_format/0`.
  """
  @type iso8601_format :: :iso8601

  @typedoc """
  An alias for the ISO8601 extended format (`2023-07-04T17:27:32Z` or
  `2023-07-04T17:27:32+04:00` with optional microsecond or millisecond
  precision).

  > Either `t:iso8601_format/0` or `t:iso8601z_format/0` may be used
  > for parsing with equivalent results.
  >
  > When formatting `t:DateTime.t/0` values, this alias will use `Z` if the
  > time zone is `Etc/UTC`, but will otherwise write the time zone offset.
  > If strict `Z` formatting is required, the caller should either *shift* the
  > value to be in `Etc/UTC` time zone or use `t:iso8601z_format/0`.
  """
  @type iso8601z_format :: :iso8601z

  @typedoc """
  An alias for timestamps including seconds as used in filenames.

  This is *similar* to ISO8601 *basic* format (`20230704T172732Z`), but does
  not include any time zone value (`20230704T172732`).
  """
  @type file_timestamp_format :: :file_timestamp
  @file_timestamp_strftime_format "%Y%m%dT%H%M%S"
  @file_timestamp_strptime_format Datix.compile!(@file_timestamp_strftime_format)

  @typedoc """
  An alias for timestamps excluding seconds as used in filenames.

  This is *similar* to `t:file_timestamp_format/0`, but does not include
  seconds (`20230704T1727`) and is therefore of lower precision.

  This format is used for SFCC-formatted filenames in the Kinetic Platform.
  """
  @type file_timestamp_nosec_format :: :file_timestamp_nosec
  @file_timestamp_nosec_strftime_format "%Y%m%dT%H%M"
  @file_timestamp_nosec_strptime_format Datix.compile!(@file_timestamp_nosec_strftime_format)

  @typedoc """
  An alias for timestamps formatted using the American 12-hour clock as
  presented by SalesForce Marketing Cloud (SFMC).

  SFMC formatted dates look like `7/4/2023 5:27:32 PM`.
  """
  @type sfmc_format :: :sfmc
  @sfmc_strftime_format "%m/%d/%Y %I:%M:%S %P"
  @sfmc_strptime_format Datix.compile!(@sfmc_strftime_format)

  @typedoc """
  An alias for parsing date strings where there may not always be two digits.
  `Date.from_iso8601/2` will fail when trying to parse `2023-7-4`, because ISO
  formatting requires leading zeros (`2023-07-04`).

  This format, when used with `DateTime` and `NaiveDateTime` will always
  produce in midnight UTC.
  """
  @type ymd_date_format :: :ymd_date
  @ymd_date_strftime_format "%Y-%m-%d"
  @ymd_date_strptime_format Datix.compile!(@ymd_date_strftime_format)

  @typedoc """
  An alias for parsing Twilio `RawDlrDoneDate` values.

  This is a copy of the Done Date in the delivery receipt (DLR) sent
  to Twilio from their carrier partners.

  The format is `YYMMDDhhmm`: a two digit year, no seconds, no time zone.

  See [Addition of RawDlrDoneDate to Delivered and Undelivered Status Webhooks]
  (https://www.twilio.com/en-us/changelog/addition-of-rawdlrdonedate-to-delivered-and-undelivered-status-webhooks)
  for more detail.
  """
  @type raw_dlr_done_date_format :: :raw_dlr_done_date
  @raw_dlr_done_date_strftime_format "%y%m%d%H%M"
  @raw_dlr_done_date_strptime_format Datix.compile!(@raw_dlr_done_date_strftime_format)

  @format_aliases %{
    posix: %{
      format: @posix_strftime_format,
      parse: @posix_strptime_format
    },
    rfc2822: %{
      format: @rfc2822_strftime_format,
      parse: @rfc2822_strptime_format
    },
    rfc2822z: %{
      format: @rfc2822z_strftime_format,
      parse: @rfc2822z_strptime_format
    },
    file_timestamp: %{
      format: @file_timestamp_strftime_format,
      parse: @file_timestamp_strptime_format
    },
    file_timestamp_nosec: %{
      format: @file_timestamp_nosec_strftime_format,
      parse: @file_timestamp_nosec_strptime_format
    },
    raw_dlr_done_date: %{
      format: @raw_dlr_done_date_strftime_format,
      parse: @raw_dlr_done_date_strptime_format
    },
    sfmc: %{
      format: @sfmc_strftime_format,
      parse: @sfmc_strptime_format
    },
    ymd_date: %{
      format: @ymd_date_strftime_format,
      parse: @ymd_date_strptime_format
    }
  }

  @supported_format_aliases Map.keys(@format_aliases)

  @typedoc """
  Supported parsing timestamp formats. Plain or compiled strptime formats are
  also supported.
  """
  @type from_format ::
          posix_format
          | rfc2822_format
          | rfc2822z_format
          | iso8601_format
          | iso8601z_format
          | file_timestamp_format
          | file_timestamp_nosec_format
          | raw_dlr_done_date_format
          | sfmc_format
          | ymd_date_format
          | strptime_format

  @typedoc """
  Supported formatting timestamp formats. Plain strftime formats are also
  supported.
  """
  @type to_format ::
          posix_format
          | rfc2822_format
          | rfc2822z_format
          | iso8601_format
          | iso8601z_format
          | file_timestamp_format
          | file_timestamp_nosec_format
          | raw_dlr_done_date_format
          | sfmc_format
          | ymd_date_format
          | strftime_format

  @typedoc """
  Extended options for parsing strings into date or timestamp structures.

  - `:strict`: Enables strict parsing. When `true`, only valid date strings are
    parsed. Otherwise, `nil` and `""` will parse to `nil`.

  Other [options][strptime-options] are passed to `Datix.strptime/3`.

  [strptime-options]: https://hexdocs.pm/datix/0.3.1/Datix.html#strptime/3-options
  """
  @type parse_option ::
          {:strict, boolean()}
          | {:preferred_date | :preferred_datetime | :preferred_time, String.t()}
          | {:am_pm_names, [{:am | :pm, String.t()}]}
          | {
              :abbreviated_day_of_week_names
              | :abbreviated_month_names
              | :day_of_week_names
              | :month_names,
              [String.t()]
            }
          | {:pivot_year, 0..99}

  @typedoc """
  The target type for parsing.

  If the parse format does not contain enough information for the target
  structure, it will be extended with zero values.

  If the parse format contains too much information, it will be
  truncated.

  This must be either `t:Date.t/0`, `t:DateTime.t/0`, or
  `t:NaiveDateTime.t/0` or the module names.
  """
  @type parse_target ::
          Date | Date.t() | DateTime | DateTime.t() | NaiveDateTime | NaiveDateTime.t()

  @typedoc """
  Extended options for formatting date or timestamp structures into strings.

  - `:strict`: Enables strict formatting. When `true`, only maps or structures
    that match `t:Calendar.date/0`, `t:Calendar.datetime/0`, or
    `t:Calendar.naive_datetime/0` will be formatted. Otherwise, `nil` or
    `t:atom/0` values will be passed through as is. All other values will still
    result in errors.

  - `:offset`: Only used when formatting a `DateTime` to `:iso8601`, this
    optional value will be passed as the `offset` parameter in
    `DateTime.to_iso8601/3`.

  Other [options][strftime-options] are passed to `Calendar.strftime/3`, if required.

  [strftime-options]: https://hexdocs.pm/elixir/Calendar.html#strftime/3-user-options
  """
  @type format_option ::
          {:strict, boolean()}
          | {:offset, nil | integer()}
          | {:preferred_date | :preferred_datetime | :preferred_time, String.t()}
          | {:am_pm_names, (:am | :pm -> String.t())}
          | {:abbreviated_day_of_week_names | :day_of_week_names, (1..7 -> String.t())}
          | {:abbreviated_month_names | :month_names, (1..12 -> String.t())}

  @doc """
  Returns the `strftime` format for the format alias or `nil` if not found.

  The format aliases `:iso8601` and `:iso8601z` return themselves.
  """
  def format_alias(:iso8601), do: :iso8601
  def format_alias(:iso8601z), do: :iso8601z

  def format_alias(value) do
    case Map.fetch(@format_aliases, value) do
      {:ok, %{format: value}} -> value
      :error -> nil
    end
  end

  @doc """
  Compiles a provided `t:strftime_format/0` into `t:Datix.compiled/0` version
  of `t:strptime_format`.
  """
  defdelegate compile_strptime_format!(format), to: Datix, as: :compile!

  @doc """
  Format a date or timestamp value as a string using the provided `format`.

  There are three special "date" value types (`nil`, `t:String.t/0`, and
  `t:atom/0`) that are passed through unmodified unless the option `strict:
  true` is passed.

  If a format is requested that the provided date or timestamp structure cannot
  format, exceptions may be thrown.
  """
  def format(value, to_format, options \\ []) do
    if allow_formatting?(value, options) do
      do_format(value, to_format, options)
    else
      raise TimestampSerdeError, "strict formatting does not allow nil, atoms, or string values"
    end
  end

  @doc """
  Parse a string value into a `t:Date.t/0`, `t:DateTime.t/0`, or
  `t:NaiveDateTime.t/0` using the provided `format`. Returns `{:ok, result}` or
  :error.

  There are two special cases handled by this parse function, unless the option
  `strict: true` is passed.

  1. A `nil` value will result in `{:ok, nil}`. This allows optional date
     values to be handled gracefully.
  2. An empty string (`""`) will result in `{:ok, nil}`. This allows optional
     date values from formats such as CSV (where empty fields are returned as
     `""`) to be handled gracefully.
  """
  def parse(value, format, parse_target, options \\ [])

  def parse(value, format, %parse_target{}, options),
    do: parse(value, format, parse_target, options)

  def parse(value, format, parse_target, options)
      when parse_target in [Date, DateTime, NaiveDateTime] do
    if allow_parsing?(value, options) do
      do_parse(value, format, parse_target, options)
    else
      :error
    end
  end

  def parse(_value, _format, _parse_target, _options), do: :error

  @doc """
  Parse a string value into a `t:Date.t/0`, `t:DateTime.t/0`, or
  `t:NaiveDateTime.t/0` using the provided `format`. Returns the result or
  throws an exception.

  See `parse/4`.
  """
  def parse!(value, format, parse_target, options \\ [])

  def parse!(value, format, %parse_target{}, options),
    do: parse!(value, format, parse_target, options)

  def parse!(value, format, parse_target, options)
      when parse_target in [Date, DateTime, NaiveDateTime] do
    if allow_parsing?(value, options) do
      do_parse!(value, format, parse_target, options)
    else
      raise TimestampSerdeError, "strict parsing does not allow nil or empty strings"
    end
  end

  def parse!(_value, _format, parse_target, _options),
    do: raise(TimestampSerdeError, "invalid parse target #{inspect(parse_target)}")

  @doc """
  Parse a string value into a `t:Date.t/0`. See `parse/4`.
  """
  def parse_date(value, format, options \\ []), do: parse(value, format, Date, options)

  @doc """
  Parse a string value into a `t:Date.t/0`. See `parse!/4`.
  """
  def parse_date!(value, format, options \\ []), do: parse!(value, format, Date, options)

  @doc """
  Parse a string value into a `t:DateTime.t/0`. See `parse/4`.
  """
  def parse_datetime(value, format, options \\ []), do: parse(value, format, DateTime, options)

  @doc """
  Parse a string value into a `t:DateTime.t/0`. See `parse!/4`.
  """
  def parse_datetime!(value, format, options \\ []),
    do: parse!(value, format, DateTime, options)

  @doc """
  Parse a string value into a `t:NaiveDateTime.t/0`. See `parse/4`.
  """
  def parse_naive_datetime(value, format, options \\ []),
    do: parse(value, format, NaiveDateTime, options)

  @doc """
  Parse a string value into a `t:NaiveDateTime.t/0`. See `parse!/4`.
  """
  def parse_naive_datetime!(value, format, options \\ []),
    do: parse!(value, format, NaiveDateTime, options)

  defp do_parse(nil, _format, _parse_target, _options), do: nil
  defp do_parse("", _format, _parse_target, _options), do: nil

  defp do_parse(value, format, parse_target, options) when format in @supported_format_aliases do
    do_parse(value, @format_aliases[format].parse, parse_target, options)
  end

  defp do_parse(value, format, parse_target, _options)
       when format in [:iso8601, :iso8601z] and parse_target in [Date, NaiveDateTime] do
    case parse_target.from_iso8601(value, :extended) do
      {:ok, result} -> {:ok, result}
      {:error, _} -> :error
    end
  end

  defp do_parse(value, format, DateTime, _options) when format in [:iso8601, :iso8601z] do
    case DateTime.from_iso8601(value, :extended) do
      {:ok, result, _utc_offset} -> {:ok, result}
      {:error, _} -> :error
    end
  end

  defp do_parse(_value, format, _parse_target, _options) when is_atom(format), do: :error

  defp do_parse(value, format, Date, options) do
    case Datix.Date.parse(value, format, options) do
      {:ok, result} -> {:ok, result}
      {:error, _} -> :error
    end
  end

  defp do_parse(value, format, DateTime, options) do
    case Datix.DateTime.parse(value, format, options) do
      {:ok, result} -> {:ok, result}
      {:error, _} -> :error
    end
  end

  defp do_parse(value, format, NaiveDateTime, options) do
    case Datix.NaiveDateTime.parse(value, format, options) do
      {:ok, result} -> {:ok, result}
      {:error, _} -> :error
    end
  end

  defp do_parse!(nil, _format, _parse_target, _options), do: nil
  defp do_parse!("", _format, _parse_target, _options), do: nil

  defp do_parse!(value, format, parse_target, options) when format in @supported_format_aliases do
    do_parse!(value, @format_aliases[format].parse, parse_target, options)
  end

  defp do_parse!(value, format, parse_target, _options)
       when format in [:iso8601, :iso8601z] and parse_target in [Date, NaiveDateTime] do
    parse_target.from_iso8601!(value, :extended)
  end

  defp do_parse!(value, format, DateTime, _options) when format in [:iso8601, :iso8601z] do
    case DateTime.from_iso8601(value, :extended) do
      {:ok, result, _utc_offset} -> {:ok, result}
      {:error, reason} -> raise TimestampSerdeError, "error parsing timestamp #{inspect(reason)}"
    end
  end

  defp do_parse!(_value, format, _parse_target, _options) when is_atom(format),
    do: raise(TimestampSerdeError, "unsupported format alias #{inspect(format)}")

  defp do_parse!(value, format, Date, options) do
    Datix.Date.parse!(value, format, options)
  end

  defp do_parse!(value, format, DateTime, options) do
    Datix.DateTime.parse!(value, format, options)
  end

  defp do_parse!(value, format, NaiveDateTime, options) do
    Datix.NaiveDateTime.parse!(value, format, options)
  end

  defp do_format(nil, _format, _options), do: nil
  defp do_format(value, _format, _options) when is_atom(value) or is_binary(value), do: value

  defp do_format(value, format, options) when format in @supported_format_aliases do
    do_format(value, @format_aliases[format].format, options)
  end

  defp do_format(%DateTime{} = value, :iso8601, options) do
    DateTime.to_iso8601(value, :extended, Keyword.get(options, :offset))
  end

  defp do_format(%DateTime{} = value, :iso8601z, _options) do
    value
    |> DateTime.shift_zone!("Etc/UTC")
    |> DateTime.to_iso8601(:extended)
  end

  defp do_format(%mod{} = value, :iso8601, _options) when mod in [Date, NaiveDateTime],
    do: mod.to_iso8601(value, :extended)

  defp do_format(%{time_zone: _} = datetime, :iso8601, options) do
    DateTime.to_iso8601(datetime, :extended, Keyword.get(options, :offset))
  end

  defp do_format(%{day: _, hour: _} = naive_datetime, :iso8601, _options) do
    NaiveDateTime.to_iso8601(naive_datetime, :extended)
  end

  defp do_format(%{day: _} = date, :iso8601, _options) do
    Date.to_iso8601(date, :extended)
  end

  defp do_format(_value, format, _options) when is_atom(format),
    do: raise(TimestampSerdeError, "unsupported format alias #{inspect(format)}")

  defp do_format(value, format, options) do
    Calendar.strftime(value, format, options)
  end

  defp allow_parsing?(value, options) do
    !(Keyword.get(options, :strict, false) && (is_nil(value) || value == ""))
  end

  defp allow_formatting?(value, options) do
    !(Keyword.get(options, :strict, false) && (is_atom(value) || is_binary(value)))
  end
end
