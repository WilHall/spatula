require_relative '../util/data'

module Spatula
    module Plugin
        def initialize(manager, id)
            @id = id
            @manager = manager
            @data = Spatula::Util::Data.new("data/plugins/#{id}/#{id}.yml")

            Spatula.dispatcher.on_event_type :config_changed, trigger: method(:config_reloaded)
        end

        def unloading!
            # do unload-y stuff
        end

        def config
            Spatula.config.dig(:plugin, :plugins, @id)
        end

        def on_event(trigger:, where: {})
            # Convenience method to call into Spatula::PluginManager.on_plugin_event with plugin ID, and to convert symbols to methods

            if not trigger.respond_to?(:call)
                # convert method names into method objects
                trigger = method(trigger.to_sym)
            end

            @manager.on_plugin_event(@id, trigger: trigger, where: where)
        end

        def on_event_type(type, trigger:, where: {})
            # Convenience method to call into Spatula::PluginManager.on_plugin_event_type with plugin ID, and to convert symbols to methods

            if not trigger.respond_to?(:call)
                # convert method names into method objects
                trigger = method(trigger.to_sym)
            end

            @manager.on_plugin_event_type(@id, type, trigger: trigger, where: where)
        end

        def log_debug(message)
            Spatula.logger.debug("PLUGIN:#{@id}") { message }
        end

        def log_error(message)
            Spatula.logger.error("PLUGIN:#{@id}") { message }
        end

        def log_fatal(message)
            Spatula.logger.fatal("PLUGIN:#{@id}") { message }
        end

        def log_info(message)
            Spatula.logger.info("PLUGIN:#{@id}") { message }
        end

        def log_warn(message)
            Spatula.logger.warn("PLUGIN:#{@id}") { message }
        end

        def loaded
            # no-op
        end

        def unloaded
            # no-op
        end

        def config_reloaded
            # no-op
        end
    end
end
