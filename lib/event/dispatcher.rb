module Spatula

    class EventDispatcher
        def initialize()
            @type_listeners = {}
            @global_listeners = []
        end

        def on_event(trigger:, where: {})
            on_event_type(nil, trigger: trigger, where: where)
        end

        def on_event_type(type, trigger:, where: {})
            if not trigger.respond_to?(:call)
                Spatula.logger.debug('DISPATCHER') {"failed to register listener for type '#{type}' (where '#{where.inspect}') because the provided trigger '#{trigger.inspect}' is not callable!"}
                return
            end

            if type.nil?
                @global_listeners << {
                    :type => type,
                    :callable => trigger,
                    :where => where
                }

                Spatula.logger.debug('DISPATCHER') {"listener registered for global events (where '#{where.inspect}')"}
            else
                @type_listeners[type] ||= []
                @type_listeners[type] << {
                    :type => type,
                    :callable => trigger,
                    :where => where
                }

                Spatula.logger.debug('DISPATCHER') {"listener registered for type '#{type}' events (where '#{where.inspect}')"}
            end
        end

        def event(type, **kwargs)
            dispatched = 0

            Spatula.logger.debug('DISPATCHER') {"event '#{type}' has been requested for dispatch"}

            # dispatch type listeners
            if @type_listeners.key?(type)
                dispatched += type_dispatched = dispatch_for_listeners(type, kwargs, @type_listeners[type])

                if type_dispatched > 0
                    Spatula.logger.debug('DISPATCHER') {"event '#{type}' was successfully dispatched to #{type_dispatched} type event listeners"}
                end
            end

            # dispatch global listeners
            if @global_listeners.length > 0
                dispatched += global_dispatched = dispatch_for_listeners(type, kwargs, @global_listeners)

                if global_dispatched > 0
                    Spatula.logger.debug('DISPATCHER') {"event '#{type}' was successfully dispatched to #{global_dispatched} global event listeners"}
                end
            end

            if dispatched == 0
                Spatula.logger.debug('DISPATCHER') {"event '#{type}' was not dispatched to any listeners"}
            end
        end

        def unregister(callable)
            @type_listeners.each do |type, listeners|
                type_listener_index = listeners.index do |listener|
                    listener[:callable] == callable
                end

                if not type_listener_index.nil?
                    listeners.delete_at(type_listener_index)
                    Spatula.logger.debug('DISPATCHER') {"unregistered type '#{type}' listener: #{callable.inspect}"}
                end
            end

            global_listener_index = @global_listeners.index do |listener|
                listener[:callable] == callable
            end

            if not global_listener_index.nil?
                @global_listeners.delete_at(global_listener_index)
                Spatula.logger.debug('DISPATCHER') {"unregistered global listener: #{callable.inspect}"}
            end
        end

        private

        def dispatch_for_listeners(type, kwargs, listeners)
            dispatched = 0
            matches_data = nil
            listeners.each do |listener|
                matches_data = nil
                if not kwargs >= listener[:where]

                    # without an exact match, see if :where contains regexes to match on
                    individual_matches = false
                    matches_data = {}
                    listener[:where].each do |key, value|
                        if kwargs.fetch(key, nil).is_a?(String)
                            if value.is_a?(Regexp)
                                match_data = value.match(kwargs[key])
                                if match_data
                                    # when we find one match, continue checking in case
                                    # another regex does not match
                                    individual_matches = true
                                    matches_data.merge!(Hash[ match_data.names.zip( match_data.captures ) ].symbolize_keys)
                                else
                                    # if we find one non-match, short-circuit because
                                    # where is an AND condition so one failure is a failure
                                    individual_matches = false
                                    break
                                end
                            else
                                # if this isn't a regex, we still need to compare the individual values
                                # otherwise it's impossible to use exact match values alongside regexes
                                if value == kwargs[key]
                                    individual_matches = true
                                else
                                    individual_matches = false
                                    break
                                end
                            end
                        end
                    end

                    if not individual_matches
                        Spatula.logger.debug('DISPATCHER') {"Skipping dispatch of event '#{type}' to listener #{listener.inspect} because where clause did not match"}
                        next
                    end
                end

                begin
                    if matches_data.nil? or matches_data.empty?
                        # when we didn't match on regexes, pass event args as named arguments
                        if listener[:callable].parameters.length == 0
                            # respect callables that don't actually want any arguments
                            listener[:callable].call()
                        else
                            listener[:callable].call(**kwargs)
                        end
                    else
                        # if we matches on regexes, pass named capture groups as named
                        # arguments and the event args as a positional hash arg
                        if listener[:callable].parameters.length == 0
                            # respect callables that don't actually want any arguments
                            listener[:callable].call()
                        else
                            listener[:callable].call(kwargs, **matches_data)
                        end
                    end
                    dispatched+=1
                rescue Exception => exception
                    Spatula.logger.debug('DISPATCHER') {"failed to dispatch event '#{type}' to listener #{listener.inspect}: #{exception} - #{exception.backtrace}"}
                    next
                end
            end

            return dispatched
        end

    end
end
