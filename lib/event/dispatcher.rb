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

        def event(type, **event_data)
            dispatched = 0

            Spatula.logger.debug('DISPATCHER') {"event '#{type}' has been requested for dispatch: #{event_data.inspect}"}

            # dispatch type listeners
            if @type_listeners.key?(type)
                dispatched += type_dispatched = dispatch_to_matching_listeners(type, event_data, @type_listeners[type])

                if type_dispatched > 0
                    Spatula.logger.debug('DISPATCHER') {"event '#{type}' was successfully dispatched to #{type_dispatched} type event listeners"}
                end
            end

            # dispatch global listeners
            if @global_listeners.length > 0
                dispatched += global_dispatched = dispatch_to_matching_listeners(type, event_data, @global_listeners)

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

        def dispatch_to_matching_listeners(event_type, event_data, listeners)
            dispatched = 0
            matches_data = nil
            listeners.each do |listener|

                # Is the listener's where clause a perfect subset of the event data (no regexes)?
                if is_perfect_match(event_data, listener[:where])
                    # dispatch the event to the listener as a match
                    dispatched += dispatch_for_match(listener, event_type, event_data)
                    next
                end

                # when it's not a perfect match, then either the where clause contains regexes, or it really
                # is not a match. we figure this out by walking the where clause and comparing values manually
                regex_capture_groups = {}
                matches = false
                listener[:where].each do |key, value|
                    # when a key that exists in the where clause doesn't exist in the event data
                    # we break, because a ket not existing is a non-match
                    break unless event_data.key?(key)

                    # if the where clause value is a regex, perform regex matching
                    if value.is_a?(Regexp)

                        # try to match the regex
                        if listener[:where][:multi]
                            matches = {}
                            event_data[key].scan(value) do |match_text|
                                matchobj = $~

                                next unless matchobj

                                matchobj.names.each_with_index do |name, i|
                                    matches[name] ||= []
                                    matches[name] << matchobj.captures[i]
                                end
                            end
                        else
                            match_data = value.match(event_data[key])
                            matches = match_data.nil? ? {} : Hash[ match_data.names.zip( match_data.captures ) ]
                        end

                        # break when the regex doesn't match
                        break if matches.empty?

                        # when the regex does match, merge the matching capture groups with
                        # ones from previous clauses
                        regex_capture_groups.merge!(matches.symbolize_keys)
                    else
                        # is the where clause value is not a regex, compare the values using ==
                        matches = (value == event_data[key])
                        break unless matches
                    end
                end

                if !matches or matches.empty?
                    Spatula.logger.debug('DISPATCHER') {"Skipping dispatch of event '#{event_type}' to listener #{listener.inspect} because where clause did not match"}
                    next
                end

                if regex_capture_groups.empty?
                    # without any regex capture groups, dispatch as a match
                    dispatched += dispatch_for_match(listener, event_type, event_data)
                else
                    # with capture groups, dispatch as a regex match
                    dispatched += dispatch_for_regex_match(listener, event_type, event_data, regex_capture_groups)
                end
            end

            return dispatched
        end

        def is_perfect_match(event_data, where)
            event_data >= where
        end

        def dispatch_for_match(listener, event_type, event_data)
            dispatched = 0

            begin
                # when we didn't match on regexes, pass event args as named arguments
                if listener[:callable].parameters.length == 0
                    # respect callables that don't actually want any arguments
                    listener[:callable].call()
                else
                    listener[:callable].call(**event_data)
                end

                dispatched = 1
            rescue Exception => exception
                Spatula.logger.debug('DISPATCHER') {"failed to dispatch event '#{event_type}' to matching listener #{listener.inspect}: #{exception} - #{exception.backtrace}"}
            end

            return dispatched
        end

        def dispatch_for_regex_match(listener, event_type, event_data, regex_capture_groups)
            dispatched = 0

            begin
                # if we matches on regexes, pass named capture groups as named
                # arguments and the event args as a positional hash arg
                if listener[:callable].parameters.length == 0
                    # respect callables that don't actually want any arguments
                    listener[:callable].call()
                else
                    listener[:callable].call(event_data, **regex_capture_groups)
                end

                dispatched = 1
            rescue Exception => exception
                Spatula.logger.debug('DISPATCHER') {"failed to dispatch event '#{event_type}' to regex-matching listener #{listener.inspect}: #{exception} - #{exception.backtrace}"}
            end

            return dispatched
        end

    end
end
