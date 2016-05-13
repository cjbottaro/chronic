defmodule ChronicTest do
  use ExUnit.Case
  doctest Chronic

  def current_year do
    {{ year, _, _ },{_, _, _}} = :calendar.universal_time
    year
  end

  test "iso8601 time" do
    { :ok, time, offset } = Chronic.parse("2012-08-02T13:00:00")
    assert time == %Calendar.NaiveDateTime{year: 2012, month: 8, day: 2, hour: 13, min: 0, sec: 0, usec: nil}
    assert offset == nil
  end

  test "iso8601 time with offset" do
    { :ok, time, offset } = Chronic.parse("2012-08-02T13:00:00+01:00")
    assert time == %Calendar.NaiveDateTime{year: 2012, month: 8, day: 2, hour: 13, min: 0, sec: 0, usec: nil}
    assert offset == 3600
  end

  test "iso8601 time with offset and ms" do
    { :ok, time, offset } = Chronic.parse("2013-08-01T19:30:00.345-07:00")
    assert time == %Calendar.NaiveDateTime{year: 2013, month: 8, day: 1, hour: 19, min: 30, sec: 0, usec: 345000}
    assert offset == -25200
  end

  test "iso8601 with UTC zone" do
    { :ok, time, offset } = Chronic.parse("2012-08-02T12:00:00Z")
    assert time == %Calendar.NaiveDateTime{year: 2012, month: 8, day: 2, hour: 12, min: 0, sec: 0, usec: nil}
    assert offset == 0
  end

  test "iso8601 with ms" do
    { :ok, time, offset } = Chronic.parse("2012-01-03 01:00:00.234567")
    assert time == %Calendar.NaiveDateTime{year: 2012, month: 1, day: 3, hour: 1, min: 0, sec: 0, usec: 234567}
    assert offset == nil
  end

  test "month and day" do
    { :ok, time, offset } = Chronic.parse("aug 3")

    assert time == %Calendar.NaiveDateTime{year: current_year, month: 8, day: 3, hour: 0, min: 0, sec: 0, usec: nil}
    assert offset == 0
  end

  test "month and ordinalized day" do
    { :ok, time, offset } = Chronic.parse("aug 3rd")

    assert time == %Calendar.NaiveDateTime{year: current_year, month: 8, day: 3, hour: 0, min: 0, sec: 0, usec: nil}
    assert offset == 0
  end

  test "month with dot and date" do
    { :ok, time, offset } = Chronic.parse("aug. 3")
    assert time == %Calendar.NaiveDateTime{year: current_year, month: 8, day: 3, hour: 0, min: 0, sec: 0, usec: nil}
    assert offset == 0
  end

  test "month and day with dash" do
    { :ok, time, offset } = Chronic.parse("aug-20")
    assert time == %Calendar.NaiveDateTime{year: current_year, month: 8, day: 20, hour: 0, min: 0, sec: 0, usec: nil}
    assert offset == 0
  end

  test "month with day, and PM time" do
    { :ok, time, offset } = Chronic.parse("aug 3 5:26pm")
    assert time == %Calendar.NaiveDateTime{year: current_year, day: 3, hour: 17, min: 26, month: 8, sec: 0, usec: 0}
    assert offset == 0
  end

  test "month with day, and AM time" do
    { :ok, time, offset } = Chronic.parse("aug 3 9:26am")
    assert time == %Calendar.NaiveDateTime{year: current_year, month: 8, day: 3, hour: 9, min: 26, sec: 0, usec: 0}
    assert offset == 0
  end

  test "month with day, with 'at' AM time" do
    { :ok, time, offset } = Chronic.parse("aug 3 at 9:26am")
    assert time == %Calendar.NaiveDateTime{year: current_year, month: 8, day: 3, hour: 9, min: 26, sec: 0, usec: 0}
    assert offset == 0
  end

  test "month with day, with 'at' AM time with seconds" do
    { :ok, time, offset } = Chronic.parse("aug 3 at 9:26:15am")
    assert time == %Calendar.NaiveDateTime{year: current_year, day: 3, hour: 9, min: 26, month: 8, sec: 15, usec: 0}
    assert offset == 0
  end

  test "month with day, with 'at' AM time with seconds and microseconds" do
    { :ok, time, offset } = Chronic.parse("may 28 at 5:32:19.764")
    assert time == %Calendar.NaiveDateTime{year: current_year, month: 5, day: 28, hour: 5, min: 32, sec: 19, usec: 764}
    assert offset == 0
  end
end
