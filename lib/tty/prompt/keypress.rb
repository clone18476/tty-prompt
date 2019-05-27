# frozen_string_literal: true

require_relative 'question'
require_relative 'timeout'
require_relative 'timer'

module TTY
  class Prompt
    class Keypress < Question
      # Create keypress question
      #
      # @param [Prompt] prompt
      # @param [Hash] options
      #
      # @api public
      def initialize(prompt, **options)
        super
        @echo    = options.fetch(:echo) { false }
        @keys    = options.fetch(:keys) { UndefinedSetting }
        @timeout = options.fetch(:timeout) { UndefinedSetting }
        @interval = options.fetch(:interval) {
          (@timeout != UndefinedSetting && @timeout < 1) ? @timeout : 1
        }
        @countdown = @timeout
        @interval_handler = -> (time) {
          unless @done
            question = render_question
            line_size = question.size
            total_lines = @prompt.count_screen_lines(line_size)
            @prompt.print(refresh(question.lines.count, total_lines))
            countdown(time)
            @prompt.print(render_question)
          end
        }
        @scheduler = Timeout.new(interval_handler: @interval_handler)

        @prompt.subscribe(self)
      end

      def countdown(value = (not_set = true))
        return @countdown if not_set
        @countdown = value
      end

      # Check if any specific keys are set
      def any_key?
        @keys == UndefinedSetting
      end

      # Check if timeout is set
      def timeout?
        @timeout != UndefinedSetting
      end

      def keypress(event)
        if any_key?
          @done = true
          @scheduler.cancel
        elsif @keys.is_a?(Array) && @keys.include?(event.key.name)
          @done = true
          @scheduler.cancel
        else
          @done = false
        end
      end

      def render_question
        header = super
        header.gsub!(/:countdown/, countdown.to_s)
        header
      end

      def process_input(question)
        time = timeout? ? Float(@timeout) : nil
        timer = Timer.new(time, Float(@interval))

        @prompt.print(render_question)
        timer.while_remaining do |remaining|
          break if @done
          @interval_handler.(remaining.round) if timeout?
          @input = @prompt.read_keypress(nonblock: true)
        end

        @evaluator.(@input)
      end

      def refresh(lines, lines_to_clear)
        @prompt.clear_lines(lines)
      end

      # Wait for keypress or timeout
      #
      # @api private
      def time(&job)
        if timeout?
          time = Float(@timeout)
          interval = Float(@interval)
          @scheduler.timeout(time, interval, &job)
        else
          job.()
        end
      end
    end # Keypress
  end # Prompt
end # TTY
