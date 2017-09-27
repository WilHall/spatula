require 'fileutils'
require 'logger'

require_relative 'multiio'

module Spatula
    module Util

        class Formatter < ::Logger::Formatter
            def call(severity, time, progname, message)
                "(#{time})[#{severity}][#{progname}] #{message}\n"
            end
        end

        class Logger
            extend Forwardable

            def_delegators :@logger, :<<, :add, :close, :datetime_format, :datetime_format=, :debug, :debug?, :error, :error?, :fatal, :fatal?, :info, :info?, :log, :unknown, :warn, :warn?, :level, :level=

            def initialize(logfile)
                @logger = ::Logger.new(
                    MultiIO.new(
                        STDOUT,
                        File.open(logfile, 'a')
                    )
                )
                @logger.formatter = Spatula::Util::Formatter.new
            end
        end

    end
end
