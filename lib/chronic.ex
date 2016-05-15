defmodule Chronic do
  @moduledoc """
    Chronic is a Pure Elixir natural language parser for times and dates
  """

  @doc """
    Parses the specified time. Will return `{:ok, time, utc_offset}` if it knows a time, otherwise `{:error, :unknown_format}`

    ## Examples

    ISO8601 times will return an offset if one is specified:

      iex> Chronic.parse("2012-08-02T13:00:00")
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 13, min: 0, month: 8, sec: 0, usec: nil, year: 2012}, nil }

      iex> Chronic.parse("2012-08-02T13:00:00+01:00")
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 13, min: 0, month: 8, sec: 0, usec: nil, year: 2012}, 3600 } 

    You can pass an option to define the "current" time for Chronic:

      iex> Chronic.parse("aug 2", currently: {{1999, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 0, min: 0, month: 8, sec: 0, usec: 0, year: 1999}, 0 }     

    **All examples here use `currently` so that they are not affected by the passing of time. You may leave the `currently` option off.**

      iex> Chronic.parse("aug 2 9am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 0, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     

      iex> Chronic.parse("aug 2 9:15am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 15, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     

      iex> Chronic.parse("aug 2nd 9:15am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 15, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     

      iex> Chronic.parse("aug. 2nd 9:15am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 15, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     

      iex> Chronic.parse("2 aug 9:15am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 15, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     

      iex> Chronic.parse("2 aug at 9:15am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 15, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     

      iex> Chronic.parse("2nd of aug 9:15am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 15, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     

      iex> Chronic.parse("2nd of aug at 9:15am", currently: {{2016, 1, 1}, {0,0,0}})
      { :ok, %Calendar.NaiveDateTime{day: 2, hour: 9, min: 15, month: 8, sec: 0, usec: 0, year: 2016}, 0 }     
  """
  def parse(time, opts \\ []) do
    case Calendar.NaiveDateTime.Parse.iso8601(time) do
      { :ok, time, offset } ->
        { :ok, time, offset }
      _ ->
        currently = opts[:currently] || :calendar.universal_time
        result = time |> preprocess |> debug(opts[:debug]) |> process(currently: currently)
        case result do
          { :ok, time } ->
            { :ok, time, 0 }
          error ->
            error
        end
    end
  end

  defp preprocess(time) do
    String.replace(time, "-", " ") |> String.split(" ") |> Chronic.Tokenizer.tokenize
  end

  # Aug 2
  defp process([month: month, number: day], [currently: currently]) do
    process_day_and_month(currently, day, month)
  end

  # Aug 2 9am
  defp process([month: month, number: day, time: time], [currently: currently]) do
    process_day_and_month(currently, day, month, time)
  end

  # Aug 2 at 9am
  defp process([month: month, number: day, word: "at", time: time], [currently: currently]) do
    process_day_and_month(currently, day, month, time)
  end

  # 2 Aug
  defp process([number: day, month: month], [currently: currently]) do
    process_day_and_month(currently, day, month)
  end

  # 2 Aug 9am
  defp process([number: day, month: month, time: time], [currently: currently]) do
    process_day_and_month(currently, day, month, time)
  end

  # 2 Aug at 9am
  defp process([number: day, month: month, word: "at", time: time], [currently: currently]) do
    process_day_and_month(currently, day, month, time)
  end

  # 2nd of Aug
  defp process([number: day, word: "of", month: month], [currently: currently]) do
    process_day_and_month(currently, day, month)
  end

  # 2nd of Aug 9am
  defp process([number: day, word: "of", month: month, time: time], [currently: currently]) do
    process_day_and_month(currently, day, month, time)
  end

  # 2nd of Aug at 9am
  defp process([number: day, word: "of", month: month, word: "at", time: time], [currently: currently]) do
    process_day_and_month(currently, day, month, time)
  end

  # 9am
  # 9:30am
  # 9:30:15am
  # 9:30:15.123456am
  defp process([time: time], [currently: currently]) do
    { :ok, combine(currently, time: time) }
  end

  # 10 to 8
  defp process([number: minutes, word: "to", number: hour], [currently: {{year, month, day}, _}]) do
    time = combine(year: year, month: month, day: day, hour: hour, minute: 0, second: 0, usec: 0)

    time |> Calendar.NaiveDateTime.subtract(minutes * 60)
  end

  # 10 to 8am
  defp process([number: minutes, word: "to", time: time], [currently: {{year, month, day}, _}]) do
    ([year: year, month: month, day: day] ++ time)
      |> combine
      |> Calendar.NaiveDateTime.subtract(minutes * 60)
  end

  # half past 2
  # half past 2pm
  defp process([word: "half", word: "past", number: hour], [currently: {{year, month, day}, _}]) do
    combine(year: year, month: month, day: day, hour: hour, minute: 0, second: 0, usec: 0)
      |> Calendar.NaiveDateTime.add(30 * 60)
  end

  # Yesterday at 9am
  defp process([word: "yesterday", word: "at", time: time], [currently: currently]) do
    process_yesterday(currently, time)
  end

  # Yesterday 9am
  defp process([word: "yesterday", time: time], [currently: currently]) do
    process_yesterday(currently, time)
  end

  # Tomorrow at 9am
  defp process([word: "tomorrow", word: "at", time: time], [currently: currently]) do
    process_tomorrow(currently, time)
  end

  # Today 9am
  defp process([word: "today", time: time], [currently: currently]) do
    process_today(currently, time)
  end

  # Today at 9am
  defp process([word: "today", word: "at", time: time], [currently: currently]) do
    process_today(currently, time)
  end

  # Tueesday
  defp process([day_of_the_week: day_of_the_week], [currently: { current_date, _}]) do
    parts = find_next_day_of_the_week(current_date, day_of_the_week) ++ [hour: 12, minute: 0, second: 0, usec: 0]
    { :ok, combine(parts) }
  end

  # Tuesday 9am
  defp process([day_of_the_week: day_of_the_week, time: time], [currently: currently]) do
    process_day_of_the_week_with_time(currently, day_of_the_week, time)
  end

  # Tuesday at 9am
  defp process([day_of_the_week: day_of_the_week, word: "at", time: time], [currently: currently]) do
    process_day_of_the_week_with_time(currently, day_of_the_week, time)
  end

  # 6 in the morning
  defp process([number: hour, word: "in", word: "the", word: "morning"], [currently: {{year, month, day}, _}]) do
    { :ok, combine(year: year, month: month, day: day, hour: hour, minute: 0, second: 0, usec: 0) }
  end

  # 6 in the evening
  defp process([number: hour, word: "in", word: "the", word: "evening"], [currently: {{year, month, day}, _}]) do
    { :ok, combine(year: year, month: month, day: day, hour: hour + 12, minute: 0, second: 0, usec: 0) }
  end

  # sat 7 in the evening
  defp process([day_of_the_week: day_of_the_week, number: hour, word: "in", word: "the", word: "evening"], [currently: currently]) do
    hour = hour + 12
    date = date_for(currently) |> find_next_day_of_the_week(day_of_the_week)

    { :ok, combine(date ++ [hour: hour, minute: 0, second: 0, usec: 0]) }
  end

  defp process(_, _opts) do
    { :error, :unknown_format }
  end

  defp process_day_and_month(currently, day, month) do
    { :ok, combine(currently, month: month, day: day) }
  end

  defp process_day_and_month(currently, day, month, time) do
    { :ok, combine(currently, month: month, day: day, time: time) }
  end

  defp process_day_of_the_week_with_time(currently, day_of_the_week, time) do
    parts = (date_for(currently) |> find_next_day_of_the_week(day_of_the_week))

    { :ok, combine(parts ++ time) }
  end

  defp process_yesterday({{year, month, day}, _}, time) do
    { :ok, datetime } = combine([year: year, month: month, day: day] ++ time)
                        |> Calendar.NaiveDateTime.subtract(86400)

    { :ok, datetime }
  end

  defp process_tomorrow({{year, month, day}, _}, time) do
    # Tomorrow at 9am
    { :ok, datetime } = combine([year: year, month: month, day: day] ++ time)
                        |> Calendar.NaiveDateTime.add(86400)

    { :ok, datetime }
  end

  defp process_today(currently, time) do
    { :ok, date_for(currently) |> date_with_time(time) }
  end


  defp combine({{year, _, _}, _}, month: month, day: day) do
    combine(year: year, month: month, day: day, hour: 0, minute: 0, second: 0, usec: 0)
  end

  defp combine({{year, _, _}, _}, month: month, day: day, time: time) do
    combine([year: year, month: month, day: day] ++ time)
  end

  defp combine({{year, month, day}, _}, time: time) do
    combine([year: year, month: month, day: day] ++ time)
  end

  defp combine(year: year, month: month, day: day, hour: hour, minute: minute, second: second, usec: usec) do
    {{ year, month, day }, { hour, minute, second }} |> Calendar.NaiveDateTime.from_erl!(usec)
  end

  defp find_next_day_of_the_week(current_date, day_of_the_week) do
    %{ year: year, month: month, day: day } = Calendar.Date.days_after(current_date) 
      |> Enum.take(7)
      |> Enum.find(fn(date) ->
        Calendar.Date.day_of_week_zb(date) == day_of_the_week
      end)
    [year: year, month: month, day: day]
  end

  defp date_for({date, _}), do: date

  defp date_with_time({year, month, day}, time) do
    parts = [year: year, month: month, day: day] ++ time

    combine(parts)
  end

  defp debug(result, debug) when debug == true do
    IO.inspect(result)
  end

  defp debug(result, _debug) do
    result
  end
end
