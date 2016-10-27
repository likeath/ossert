# frozen_string_literal: true
module Ossert
  module Fetch
    class StackOverflow
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :community

      def initialize(project)
        @project = project
        @client = SimpleClient.new('https://api.stackexchange.com/2.2/', '')
      end

      def questions_count(from, to)
        questions_count_request('questions', from, to)
      end

      def no_answers_questions_count(from, to)
        questions_count_request('questions/no-answers', from, to)
      end

      def process
        process_quarters_stats
        process_total_stats
      end

      private

      def questions_count_request(api_method, from, to)
        @client
          .get(api_method, { fromdate: from.to_i, todate: to.to_i }.merge(base_request_options))
          .fetch('total')
      end

      def process_quarters_stats
        community.quarters.with_quarters_intervals do |from, to|
          total_questions_count = questions_count(from, to)

          community.quarters[from].stack_overflow_questions_count = total_questions_count

          community.quarters[from].stack_overflow_answered_questions_percent =
            answered_questions_percent(
              total_questions_count,
              no_answers_questions_count(from, to)
            )
        end
      end

      def process_total_stats
        total_questions_count = questions_count(*total_count_time_boundaries)

        community.total.stack_overflow_questions_count = total_questions_count

        community.total.stack_overflow_answered_questions_percent =
          answered_questions_percent(
            total_questions_count,
            no_answers_questions_count(*total_count_time_boundaries)
          )
      end

      def base_request_options
        { tagged: project.name, filter: 'total', site: 'stackoverflow', key: ENV['STACKEXCHANGE_KEY'] }.compact
      end

      def total_count_time_boundaries
        @_total_count_time_boundaries ||= [10.years.ago, Time.current.beginning_of_day]
      end

      def answered_questions_percent(total_questions_count, no_answers_questions_count)
        return if total_questions_count.zero?

        answered_questions_count = total_questions_count - no_answers_questions_count
        ((answered_questions_count.to_f * 100) / total_questions_count).round(2)
      end
    end
  end
end
