# frozen_string_literal: true
module Ossert
  # Public: Class for data divided by quarters. Each quarter instantiates some statistics class.
  # Contains methods for quarters calculations, such as grouping, preview and other.
  class QuartersStore
    attr_reader :quarters, :data_klass, :start_date, :end_date

    # Public: Build quarter intervals for given period.
    #   Non-quarter boundaries are expanded to quarters.
    #
    # from - Numeric or DateTime of period start
    # to - Numeric or DateTime of period finish
    #
    # Returns Array of interval boundaries as timestamps
    def self.build_quarters_intervals(from: 1.year.ago, to: Time.current)
      interval_start = Time.at(from).beginning_of_quarter
      finish = Time.at(to).end_of_quarter
      intervals = []

      while interval_start <= finish
        interval_end = interval_start.end_of_quarter
        intervals << [interval_start.to_i, interval_end.to_i]
        interval_start = interval_end + 1.second
      end

      intervals
    end

    # Public: Instantiate QuarterStore
    #
    # data_klass - the Object for quarter data storage, to be compatable it
    #              should implement:
    #                - class method #metrics returns Array of metric names;
    #                - instance method #metric_values returns values of metrics
    #                  in same order.
    #
    # Returns QuarterStore instance.
    def initialize(data_klass)
      @data_klass = data_klass
      @quarters = {}
      @start_date = Time.now
      @end_date = Time.now
    end

    # Public: Strict fetch of quarter for given date
    #
    # date - the String, Numeric or DateTime to seek begining of quarter for.
    #
    # Returns quarter Object or KeyError will be raised.
    def fetch(date)
      quarters.fetch date_to_start(date)
    end

    # Public: Find or create quarter for given date.
    #
    # date - the String, Numeric or DateTime to seek begining of quarter for.
    #
    # Returns quarter Object.
    def find_or_create(date)
      quarters[date_to_start(date)] ||= data_klass.new
    end
    alias [] find_or_create

    # Public: Find closest begining of quarter for given date.
    #
    # date - the String, Numeric or DateTime to seek begining of quarter for.
    #
    # Returns begining of quarter DateTime.
    def date_to_start(date)
      if date.is_a? String
        # Alternative, but more expensive: DateTime.parse(value).beginning_of_quarter.to_i
        DateTime.new(*date.split('-').map(&:to_i)).beginning_of_quarter.to_i
      else
        Time.at(date).to_date.to_time(:utc).beginning_of_quarter.to_i
      end
    end

    # Public: Prepare quarters to preview.
    #
    # Returns sorted Hash of quarter date and its data.
    def preview
      quarters.sort.map { |unix_timestamp, quarter| [Time.at(unix_timestamp), quarter] }.to_h
    end

    # Public: Get quarters metric values aggregated for last year.
    #
    # offset - the Numeric (default: 1) in quarters for offset of when "last year" should ends
    #
    # Returns Array of quarter metric values aggregated for last year.
    def last_year_data(offset = 1)
      last_year_as_hash(offset).values
    end

    # Public: Get quarters metric values aggregated for last year.
    #
    # offset - the Numeric (default: 1) in quarters for offset of when "last year" should ends
    #
    # Returns Hash of quarter metrics and its values aggregated for last year.
    def last_year_as_hash(offset = 1)
      last_year_metrics = data_klass.metrics.zip(
        quarters.sort.last(4 + offset)
                     .take(4)
                     .map { |_, quarter| quarter.metric_values }
                     .transpose
                     .map { |x| x.reduce(:+) }
      ).to_h

      data_klass.aggregated_metrics.each { |metric| last_year_metrics[metric] /= 4.0 }

      last_year_metrics
    end

    # Public: Fill quarter bounds and wholes in periods from first to last quarter.
    # It will assign @start_date and @end_date of QuarterStore instance.
    # Should be called after all data is gathered and we ready for data presentation.
    #
    # Returns nothing.
    def fullfill!
      return if quarters.empty?

      periods_range = with_quarters_dates do |period|
        find_or_create Time.at(period)
      end

      @start_date = Time.at(periods_range.first)
      @end_date = Time.at(periods_range.last)
    end

    def with_quarters_dates
      sorted_quarters = quarters.keys.sort
      (sorted_quarters.first..sorted_quarters.last).step(93.days) { |period| yield(period) }
    end

    # Public: Iterate (and yields) through quarters in descending order
    #
    # Yields the Numeric UNIX-timestamp beginning of quarter
    #        the Object for quarter data
    #
    # Returns Array of sorted pairs of time and quarter object.
    def reverse_each_sorted
      quarters.sort.reverse.map { |time, quarter| yield(time, quarter) }
    end

    # Public: Iterate (and yields) through quarters in ascending order
    #
    # Yields the Numeric UNIX-timestamp beginning of quarter
    #        the Object for quarter data
    #
    # Returns Array of sorted pairs of time and quarter object.
    def each_sorted
      quarters.sort.map { |time, quarter| yield(time, quarter) }
    end

    # Public: Generate JSON for current data structure.
    #         Keys are UNIX-timestamps (beginning of each quarter),
    #         values are quarter objects explicitly converted to Hash.
    #
    # Returns String contains valid JSON.
    def to_json
      hash = quarters.each_with_object({}) do |(time, quarter), result|
        result[time] = quarter.to_hash
      end
      JSON.generate(hash)
    end

    # Public: Iterate (and yields) through quarters intervals
    #         Uses existed quarters if possible,
    #         otherwise build quarters for year
    #
    # Yields the Numeric UNIX-timestamps of beginning and end of qaurter
    #
    # Returns nothing
    def with_quarters_intervals
      enumerator = if quarters.present?
                     quarters
                       .keys.sort
                       .push(Time.current.end_of_quarter.to_i)
                       .each_cons(2)
                   else
                     self.class.build_quarters_intervals.each
                   end
      enumerator.each { |start, finish| yield(start, finish) }
      nil
    end
  end
end
