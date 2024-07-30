defmodule KineticLib.Timestamp do
  @moduledoc """
  This module offers extension functions to work with date and time structures.

  Any third-party libraries we use for working with date and time structures
  have delegated functions defined here to prevent dependency leakage.
  """

  @doc "Returns `true` if `left` is strictly before `right`."
  defdelegate before?(left, right), to: DateTime

  @doc "Returns `true` if `left` is strictly after `right`."
  defdelegate after?(left, right), to: DateTime

  @doc """
  Returns a `t:DateTime.t/0` or `t:NaiveDateTime.t/0` for the beginning of the
  day.
  """
  def beginning_of_day(%DateTime{} = value) do
    value
    |> NaiveDateTime.beginning_of_day()
    |> DateTime.from_naive!(value.time_zone)
  end

  def beginning_of_day(value), do: NaiveDateTime.beginning_of_day(value)

  @doc """
  Returns a `t:DateTime.t/0` or `t:NaiveDateTime.t/0` for the end of the day.
  """
  def end_of_day(%DateTime{} = value) do
    value
    |> NaiveDateTime.end_of_day()
    |> DateTime.from_naive!(value.time_zone)
  end

  def end_of_day(value), do: NaiveDateTime.end_of_day(value)

  @doc """
  Polymorphic support for adding time units to `t:DateTime.t/0`,
  `t:NaiveDateTime.t/0`, or `t:Time.t/0`.
  """
  def add_time(
        value,
        amount_to_add,
        unit \\ :second,
        time_zone_database \\ Calendar.get_time_zone_database()
      )

  def add_time(%mod{} = value, amount_to_add, unit, _time_zone_database)
      when mod in [NaiveDateTime, Time] do
    mod.add(value, amount_to_add, unit)
  end

  def add_time(%DateTime{} = value, amount_to_add, unit, time_zone_database) do
    DateTime.add(value, amount_to_add, unit, time_zone_database)
  end

  @doc """
  Polymorphic support for adding extended date units to `t:Date.t/0`, `t:DateTime.t/0`,
  or `t:NaiveDateTime.t/0`.

  The extended date units are:

  - `:week`: add `7 * amount_to_add` days.
  - `:month`: add `amount_to_add` months.
  - `:month_end`: add `amount_to_add` months, but if the date is at the last
    day of the month, the date will remain the last day of the month.
  - `:year`: add `amount_to_add` years. February 29th will be shifted to March
    1 when going from a non-leap year to a leap year.
  - `:year_end`: add `amount_to_add` years. February 29th will be shifted to
    February 28th when going from a non-leap year to a leap year.

  The difference between `:month` and `:month_end` is subtle, but important:

      iex> Timestamp.add_date(~D[2020-02-29], 1, :month)
      ~D[2020-03-29]
      iex> Timestamp.add_date(~D[2020-02-29], 1, :month_end)
      ~D[2020-03-31]
      iex> Timestamp.add_date(~D[2020-02-29], -1, :month)
      ~D[2020-01-29]
      iex> Timestamp.add_date(~D[2020-02-29], -1, :month_end)
      ~D[2020-01-31]
  """
  def add_date(
        value,
        amount_to_add,
        unit \\ :day,
        time_zone_database \\ Calendar.get_time_zone_database()
      )

  def add_date(%Date{} = value, amount_to_add, :day, _time_zone_database) do
    Date.add(value, amount_to_add)
  end

  def add_date(%DateTime{} = value, amount_to_add, :day, time_zone_database) do
    DateTime.add(value, amount_to_add, :day, time_zone_database)
  end

  def add_date(%NaiveDateTime{} = value, amount_to_add, :day, _time_zone_database) do
    NaiveDateTime.add(value, amount_to_add, :day)
  end

  def add_date(value, amount_to_add, :week, time_zone_database) do
    add_date(value, amount_to_add * 7, :day, time_zone_database)
  end

  def add_date(
        %{calendar: calendar, year: year, month: month, day: day} = value,
        amount_to_add,
        unit,
        _time_zone_database
      )
      when unit in [:year, :year_end] do
    new_year = year + amount_to_add
    shifted = %{value | year: new_year}

    cond do
      new_year < 0 ->
        {:error, :shift_to_invalid_date}

      month == 2 and day == 29 and calendar.leap_year?(year) and !calendar.leap_year?(new_year) ->
        if unit == :year do
          %{shifted | month: 3, day: 1}
        else
          %{shifted | day: 28}
        end

      true ->
        shifted
    end
  end

  def add_date(value, amount_to_add, unit, _time_zone_database)
      when unit in [:month, :month_end] do
    add_date_months(value, amount_to_add, unit == :month_end)
  end

  @doc """
  Ensures that the timestamp microsecond formatting is always using
  microseconds.
  """
  def pad_usec(%{microsecond: {_, 6}} = time), do: time

  def pad_usec(%{microsecond: {value, digits}} = time) when digits != 6,
    do: %{time | microsecond: {value, 6}}

  @doc """
  Truncates the provided date or timestamp to the specified precision
  (`:microsecond`, `:millisecond`, `:second`, `:minute`, `:hour`, or `:day`).

  The given date or timestamp is returned unchanged if it already has lower
  precision than the given precision.

  When `t:Time.t/0` values are provided `:day`, it is the same as midnight.
  """
  def truncate(%Date{} = date, _precision), do: date

  def truncate(t, precision)
      when precision in [:microsecond, :millisecond, :second],
      do: %{t | microsecond: Calendar.truncate(t.microsecond, precision)}

  def truncate(t, :minute), do: %{t | second: 0, microsecond: {0, 0}}

  def truncate(t, :hour), do: %{t | minute: 0, second: 0, microsecond: {0, 0}}

  def truncate(t, :day), do: %{t | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

  @doc """
  Converts the given `t:Date.t/0`, `t:DateTime.t/0`, or `t:NaiveDateTime.t/0`
  to `t:Date.t/0`.
  """
  def to_date(%Date{} = t), do: t
  def to_date(%mod{} = t) when mod in [DateTime, NaiveDateTime], do: mod.to_date(t)

  @doc """
  Converts the given `t:Date.t/0`, `t:DateTime.t/0`, or `t:NaiveDateTime.t/0`
  to `t:DateTime.t/0`. See `Date.from_naive/3` for possible return values.

  The time zone string defaults to `"Etc/UTC"`. The time zone string is
  discarded when "converting" a `t:DateTime.t/0`.
  """
  def to_datetime(t, tz, tz_db \\ Calendar.get_time_zone_database())

  def to_datetime(%DateTime{} = t, _tz, _tz_db), do: t

  def to_datetime(%Date{} = d, tz, tz_db),
    do: to_datetime(NaiveDateTime.new!(d, ~T[00:00:00]), tz, tz_db)

  def to_datetime(%NaiveDateTime{} = t, tz, tz_db), do: DateTime.from_naive(t, tz, tz_db)

  @doc """
  Converts the given `t:Date.t/0`, `t:DateTime.t/0`, or `t:NaiveDateTime.t/0`
  to `t:DateTime.t/0`.

  The time zone string defaults to `"Etc/UTC"`. The time zone string is
  discarded when "converting" a `t:DateTime.t/0`.
  """
  def to_datetime!(t, tz \\ "Etc/UTC", tz_db \\ Calendar.get_time_zone_database())

  def to_datetime!(%DateTime{} = t, _tz, _tz_db), do: t

  def to_datetime!(%Date{} = d, tz, tz_db),
    do: to_datetime!(NaiveDateTime.new!(d, ~T[00:00:00]), tz, tz_db)

  def to_datetime!(%NaiveDateTime{} = t, tz, tz_db), do: DateTime.from_naive!(t, tz, tz_db)

  @doc """
  Converts the given `t:Date.t/0`, `t:DateTime.t/0`, or `t:NaiveDateTime.t/0`
  to `t:NaiveDateTime.t/0`.
  """
  def to_naive_datetime(%Date{} = d), do: NaiveDateTime.new!(d, ~T[00:00:00])
  def to_naive_datetime(%NaiveDateTime{} = t), do: t
  def to_naive_datetime(%DateTime{} = t), do: DateTime.to_naive(t)

  @doc """
  Create a current date based on the provided timezone. When `timezone` is
  "Etc/UTC", it is the equivalent of `Date.utc_today/1`.
  """
  def current_date(timezone \\ "Etc/UTC") do
    timezone
    |> DateTime.now!()
    |> DateTime.to_date()
  end

  defp add_date_months(value, 0, _sticky_eom?), do: value

  defp add_date_months(
         %{calendar: calendar, year: year, month: month, day: day} = value,
         amount_to_add,
         sticky_eom?
       )
       when amount_to_add > 0 do
    add_years = div(amount_to_add, 12)
    add_months = rem(amount_to_add, 12)

    {new_year, new_month} =
      if month + add_months <= 12 do
        {year + add_years, month + add_months}
      else
        {year + add_years + 1, month + add_months - 12}
      end

    new_value = %{value | year: new_year, month: new_month}
    current_ldom = calendar.days_in_month(year, month)
    new_ldom = calendar.days_in_month(new_year, new_month)

    if (sticky_eom? and day == current_ldom) or day > new_ldom do
      %{new_value | day: new_ldom}
    else
      new_value
    end
  end

  defp add_date_months(
         %{calendar: calendar, year: year, month: month, day: day} = value,
         amount_to_add,
         sticky_eom?
       ) do
    add_years = div(amount_to_add, 12)
    add_months = rem(amount_to_add, 12)

    {new_year, new_month} =
      if month + add_months < 1 do
        {year + add_years - 1, month + add_months + 12}
      else
        {year + add_years, month + add_months}
      end

    if new_year < 0 do
      {:error, :shift_to_invalid_date}
    else
      new_value = %{value | year: new_year, month: new_month}
      current_ldom = calendar.days_in_month(year, month)
      new_ldom = calendar.days_in_month(new_year, new_month)

      if (sticky_eom? and day == current_ldom) or day > new_ldom do
        %{new_value | day: new_ldom}
      else
        new_value
      end
    end
  end
end
