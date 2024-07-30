defmodule KineticLib.TimestampTest do
  use ExUnit.Case

  alias KineticLib.Timestamp

  @test_suite %{
    ~U[2020-03-01 13:25:32Z] => %{
      {-1, :day} => ~U[2020-02-29 13:25:32Z],
      {1, :day} => ~U[2020-03-02 13:25:32Z],
      {-1, :week} => ~U[2020-02-23 13:25:32Z],
      {1, :week} => ~U[2020-03-08 13:25:32Z],
      {-52, :week} => ~U[2019-03-03 13:25:32Z],
      {52, :week} => ~U[2021-02-28 13:25:32Z],
      {-1, :month} => ~U[2020-02-01 13:25:32Z],
      {1, :month} => ~U[2020-04-01 13:25:32Z],
      {-1, :month_end} => ~U[2020-02-01 13:25:32Z],
      {1, :month_end} => ~U[2020-04-01 13:25:32Z],
      {-1, :year} => ~U[2019-03-01 13:25:32Z],
      {1, :year} => ~U[2021-03-01 13:25:32Z]
    },
    ~U[2020-02-29 13:25:32Z] => %{
      {-1, :month} => ~U[2020-01-29 13:25:32Z],
      {1, :month} => ~U[2020-03-29 13:25:32Z],
      {-36, :month} => ~U[2017-02-28 13:25:32Z],
      {36, :month} => ~U[2023-02-28 13:25:32Z],
      {-48, :month} => ~U[2016-02-29 13:25:32Z],
      {48, :month} => ~U[2024-02-29 13:25:32Z],
      {-1, :month_end} => ~U[2020-01-31 13:25:32Z],
      {1, :month_end} => ~U[2020-03-31 13:25:32Z],
      {-36, :month_end} => ~U[2017-02-28 13:25:32Z],
      {36, :month_end} => ~U[2023-02-28 13:25:32Z],
      {-48, :month_end} => ~U[2016-02-29 13:25:32Z],
      {48, :month_end} => ~U[2024-02-29 13:25:32Z],
      {-1, :year} => ~U[2019-03-01 13:25:32Z],
      {1, :year} => ~U[2021-03-01 13:25:32Z],
      {-4, :year} => ~U[2016-02-29 13:25:32Z],
      {4, :year} => ~U[2024-02-29 13:25:32Z],
      {-1, :year_end} => ~U[2019-02-28 13:25:32Z],
      {1, :year_end} => ~U[2021-02-28 13:25:32Z],
      {-4, :year_end} => ~U[2016-02-29 13:25:32Z],
      {4, :year_end} => ~U[2024-02-29 13:25:32Z]
    },
    ~U[2019-02-28 13:25:32Z] => %{
      {-1, :month} => ~U[2019-01-28 13:25:32Z],
      {1, :month} => ~U[2019-03-28 13:25:32Z],
      {-1, :month_end} => ~U[2019-01-31 13:25:32Z],
      {1, :month_end} => ~U[2019-03-31 13:25:32Z],
      {-2, :month} => ~U[2018-12-28 13:25:32Z],
      {2, :month} => ~U[2019-04-28 13:25:32Z],
      {-2, :month_end} => ~U[2018-12-31 13:25:32Z],
      {2, :month_end} => ~U[2019-04-30 13:25:32Z]
    },
    ~U[2020-01-31 13:25:32Z] => %{
      {-2, :month} => ~U[2019-11-30 13:25:32Z],
      {2, :month} => ~U[2020-03-31 13:25:32Z],
      {-2, :month_end} => ~U[2019-11-30 13:25:32Z],
      {2, :month_end} => ~U[2020-03-31 13:25:32Z]
    },
    ~U[2020-11-30 13:25:32Z] => %{
      {-1, :month} => ~U[2020-10-30 13:25:32Z],
      {1, :month} => ~U[2020-12-30 13:25:32Z],
      {-1, :month_end} => ~U[2020-10-31 13:25:32Z],
      {1, :month_end} => ~U[2020-12-31 13:25:32Z],
      {-2, :month} => ~U[2020-09-30 13:25:32Z],
      {2, :month} => ~U[2021-01-30 13:25:32Z],
      {-2, :month_end} => ~U[2020-09-30 13:25:32Z],
      {2, :month_end} => ~U[2021-01-31 13:25:32Z]
    }
  }

  @target_modules %{
    Date => &DateTime.to_date/1,
    DateTime => & &1,
    NaiveDateTime => &DateTime.to_naive/1,
    Time => &DateTime.to_time/1
  }

  for {target_module, converter} <- @target_modules do
    # Convert the DateTime values in @test_suite to the target module.
    module_test_suite =
      Map.new(@test_suite, fn {origin, tests} ->
        {converter.(origin),
         Map.new(tests, fn {action, expected} -> {action, converter.(expected)} end)}
      end)

    target_module_name = String.replace(to_string(target_module), "Elixir.", "")

    # For target modules that support Time adjustments, test Timestamp.add_time/4
    if target_module != Date do
      time_value = Macro.escape(hd(Map.keys(module_test_suite)))

      describe "add_time/4 with #{target_module_name}" do
        test "passes through to #{target_module_name}.add" do
          value = unquote(time_value)
          target_module = unquote(target_module)

          assert Timestamp.add_time(value, 2) == target_module.add(value, 2, :second)
          assert Timestamp.add_time(value, 2, :second) == target_module.add(value, 2, :second)
          assert Timestamp.add_time(value, 2, :minute) == target_module.add(value, 2, :minute)
          assert Timestamp.add_time(value, 2, :hour) == target_module.add(value, 2, :hour)
        end
      end
    end

    # For target modules that support Date adjustments, test Timestamp.add_date/4
    if target_module != Time do
      describe "add_date/4 with #{target_module_name}" do
        for {origin, tests} <- module_test_suite, {{amount, unit}, expected} <- tests do
          name = "#{origin} add #{amount} #{unit} == #{expected}"
          origin = Macro.escape(origin)
          expected = Macro.escape(expected)

          test name do
            assert unquote(expected) ==
                     Timestamp.add_date(unquote(origin), unquote(amount), unquote(unit))
          end
        end
      end
    end
  end
end
