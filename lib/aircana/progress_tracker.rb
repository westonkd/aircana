# frozen_string_literal: true

require "tty-spinner"
require "tty-progressbar"

module Aircana
  class ProgressTracker
    def self.with_spinner(message, success_message: nil)
      spinner = TTY::Spinner.new("[:spinner] #{message}", format: :dots, clear: true)
      spinner.auto_spin

      begin
        result = yield
        spinner.success("✅ #{success_message || message}")
        result
      rescue StandardError => e
        spinner.error("❌ #{message} failed")
        raise e
      end
    end

    def self.with_progress_bar(total, message, &)
      if total <= 1
        # For single items, use a spinner instead
        with_spinner(message, &)
      else
        # For multiple items, show progress bar
        bar = TTY::ProgressBar.new(
          "#{message} [:bar] :current/:total (:percent) :elapsed",
          total: total,
          bar_format: :box
        )

        yield(bar)
        bar
      end
    end

    def self.with_batch_progress(items, message, &)
      total = items.size

      if total <= 1
        with_spinner("#{message} (#{total} item)", &)
      else
        with_progress_bar(total, message) do |bar|
          items.each_with_index do |item, index|
            result = yield(item, index)
            bar.advance(1)
            result
          end
        end
      end
    end
  end
end
