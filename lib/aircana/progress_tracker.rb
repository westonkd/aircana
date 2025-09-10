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
      return with_spinner(message, &) if total <= 1

      create_and_use_progress_bar(total, message, &)
    end

    def self.create_and_use_progress_bar(total, message)
      bar = TTY::ProgressBar.new(
        "#{message} [:bar] :current/:total (:percent) :elapsed",
        total: total,
        bar_format: :box
      )
      yield(bar)
      bar
    end

    def self.with_batch_progress(items, message, &)
      total = items.size
      return with_spinner("#{message} (#{total} item)", &) if total <= 1

      process_batch_with_progress(items, total, message, &)
    end

    def self.process_batch_with_progress(items, total, message)
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
