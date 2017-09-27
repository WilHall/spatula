require 'yaml'

require_relative 'config.rb'

module Spatula
    module Util

        class Data < Config
            def_delegators :@data, :[]=

            def save!
                File.write(@config_filepath, YAML.dump(@data))
            end
        end

    end
end
