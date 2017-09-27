require 'fileutils'
require 'listen'
require 'yaml'

module Spatula
    module Util

        class Config
            extend Forwardable

            def_delegators :@data, :[], :fetch, :dig, :key?, :include?, :member?, :keys, :values

            def initialize(config_filepath)
                @config_filepath = config_filepath
                @change_listeners = []

                FileUtils.mkdir_p(File.dirname(@config_filepath))
                FileUtils.touch(config_filepath)

                # load immediatly
                changed

                listen_dir = File.dirname(@config_filepath)
                listen_regex = /^#{Regexp.quote(File.basename(@config_filepath))}$/
                listener = Listen.to(listen_dir, relative: true, only: listen_regex) {
                    changed
                }
                listener.start
            end

            def on_change(&block)
                @change_listeners << block
            end

            private

            def changed
                @data = YAML.load_file(@config_filepath)

                if @data === false
                    @data = {}
                end

                for listener in @change_listeners
                    listener.call(self)
                end
            end
        end

    end
end
