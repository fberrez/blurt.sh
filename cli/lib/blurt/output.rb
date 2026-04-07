# frozen_string_literal: true

module Blurt
  module Output
    COLORS = {
      green: "\e[32m",
      red: "\e[31m",
      yellow: "\e[33m",
      bold: "\e[1m",
      reset: "\e[0m"
    }.freeze

    module_function

    def success(msg)
      puts "#{checkmark} #{msg}"
    end

    def error(msg)
      $stderr.puts colorize("#{cross} #{msg}", :red)
    end

    def warn(msg)
      $stderr.puts colorize("! #{msg}", :yellow)
    end

    def info(msg)
      puts msg
    end

    def checkmark
      color? ? "\e[32m\u2714\e[0m" : "[ok]"
    end

    def cross
      color? ? "\e[31m\u2718\e[0m" : "[error]"
    end

    def colorize(text, color)
      return text unless color?

      "#{COLORS[color]}#{text}#{COLORS[:reset]}"
    end

    def color?
      $stdout.tty?
    end
  end
end
