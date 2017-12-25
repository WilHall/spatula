require 'fileutils'

require_relative 'plugin'

module Spatula

    class PluginManager
        def initialize()
            @plugins = {}
            @plugin_event_callables = {}

            # Allow incoming plugin operations via the event dispatcher
            Spatula.dispatcher.on_event_type :load_plugin, trigger: method(:load_plugin)
            Spatula.dispatcher.on_event_type :unload_plugin, trigger: method(:unload_plugin)
            Spatula.dispatcher.on_event_type :reload_plugin, trigger: method(:reload_plugin)

            # Allow slack messages to trigger plugin operations as well
            Spatula.dispatcher.on_event_type :slack_message,
                where: {
                    :text_mentions_me => true,
                    :text => / load (?<plugin_id>.*)$/
                },
                trigger: lambda { |args, plugin_id:|
                    result, result_message = load_plugin(plugin_id)
                    Spatula.helper.result_message(
                        conversation: args[:channel],
                        text: result_message,
                        success: result
                    )
                }
            Spatula.dispatcher.on_event_type :slack_message,
                where: {
                    :text_mentions_me => true,
                    :text => / unload (?<plugin_id>.*)$/
                },
                trigger: lambda {|args, plugin_id:|
                    result, result_message = unload_plugin(plugin_id)
                    Spatula.helper.result_message(
                        conversation: args[:channel],
                        text: result_message,
                        success: result
                    )
                }
            Spatula.dispatcher.on_event_type :slack_message,
                where: {
                    :text_mentions_me => true,
                    :text => / reload (?<plugin_id>.*)$/
                },
                trigger: lambda { |args, plugin_id:|
                    result, result_message = reload_plugin(plugin_id)
                    Spatula.helper.result_message(
                        conversation: args[:channel],
                        text: result_message,
                        success: result
                    )
                }

            Spatula.logger.debug('PLUGIN_MANAGER') {"Plugin manager has been initialized"}

            load_configured_plugins
        end

        def is_loaded(id)
            id = id.to_sym
            @plugins.include? id
        end

        def load_plugin(id)
            id = id.to_sym
            if is_loaded(id)
                result_message = "Cannot load plugin '#{id}': plugin is already loaded"
                Spatula.logger.debug('PLUGIN_MANAGER') { result_message }
                return false, result_message
            end

            begin
                plugin_file = "plugins/#{id}/#{id}.rb"
                plugin_module = Module.new
                plugin_module.module_eval(File.read(plugin_file))
                plugin_class_name = "#{id.to_s.split('_').collect(&:capitalize).join}Plugin"
                plugin_class = plugin_module.const_get(plugin_class_name)
                plugin_class.class_eval do
                    include Spatula::Plugin
                end
                plugin_instance = plugin_class.new(self, id)
            rescue Exception => exception
                Spatula.logger.debug('PLUGIN_MANAGER') { "Failed to load plugin '#{id}': #{exception} - #{exception.backtrace}" }
                return false, "Failed to load plugin '#{id}'"
            end

            @plugins[id] = {
                :id => id,
                :file => plugin_file,
                :module => plugin_module,
                :class_name => plugin_class_name,
                :class => plugin_class,
                :instance => plugin_instance
            }

            # let the plugin know it has been loaded
            plugin_instance.loaded

            result_message = "Loaded plugin '#{id}'"
            Spatula.logger.debug('PLUGIN_MANAGER') { result_message }
            Spatula.dispatcher.event :plugin_loaded, id: id

            return true, result_message
        end

        def unload_plugin(id)
            id = id.to_sym
            if not is_loaded(id)
                result_message = "Cannot unload plugin '#{id}': plugin is not loaded"
                Spatula.logger.debug('PLUGIN_MANAGER') { result_message }
                return false, result_message
            end

            # tell the plugin parent class we're unloading before actually unloading anything
            @plugins[id][:instance].unloading!

            if @plugin_event_callables.key?(id)
                @plugin_event_callables[id].each do |listener|
                    Spatula.dispatcher.unregister(listener)
                end
            end

            # tell the plugin child class it has been unloaded right before we de-reference it
            @plugins[id][:instance].unloaded
            @plugins.delete(id)

            result_message = "Unloaded plugin '#{id}'"
            Spatula.logger.debug('PLUGIN_MANAGER') { result_message }
            Spatula.dispatcher.event :plugin_unloaded, id: id

            return true, result_message
        end

        def reload_plugin(id)
            id = id.to_sym
            if not is_loaded(id)
                result_message = "Cannot reload plugin '#{id}': plugin is not loaded"
                Spatula.logger.debug('PLUGIN_MANAGER') { result_message }
                return false, result_message
            end

            result, result_message = unload_plugin(id)
            if not result
                return false, result_message
            end

            result, result_message = load_plugin(id)
            if not result
                return false, result_message
            end

            result_message = "Reloaded plugin '#{id}'"
            Spatula.logger.debug('PLUGIN_MANAGER') { result_message }
            Spatula.dispatcher.event :plugin_reloaded, id: id

            return true, result_message
        end

        def on_plugin_event(id, trigger:, where: {})
            # Wrapper around Spatula::EventDispatcher.on_event
            # which tracks registered callables so they can be unregistered
            # when plugins unload
            @plugin_event_callables[id] ||= []
            @plugin_event_callables[id] << trigger

            Spatula.dispatcher.on_event(trigger: trigger, where: where)
        end

        def on_plugin_event_type(id, type, trigger:, where: {})
            # Wrapper around Spatula::EventDispatcher.on_event_type
            # which tracks registered callables so they can be unregistered
            # when plugins unload
            @plugin_event_callables[id] ||= []
            @plugin_event_callables[id] << trigger

            Spatula.dispatcher.on_event_type(type, trigger: trigger, where: where)
        end

        private

        def load_configured_plugins
            Spatula.config[:plugin][:plugins].each do |id, config|
                load_plugin(id)
            end
        end
    end

end
