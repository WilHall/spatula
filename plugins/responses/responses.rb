class ResponsesPlugin

    @@actions = {
        react: ['react', 'react with'],
        respond: ['say', 'reply', 'reply with', 'respond']
    }

    def loaded
        action_phrases = []
        @@actions.each do |action, phrases|
            action_phrases.push(*phrases)
        end
        action_phrases_string = action_phrases.join('|')

        on_event_type :slack_message,
            where: {
                addresses_me: true,
                text_unescaped: /(?:when you hear|when someone says) (?<trigger>.{3,}?) (?<action_phrase>#{action_phrases_string}) (?<response>.*)/
            },
            trigger: method(:define_trigger)

        on_event_type :slack_message,
            where: {
                addresses_me: true,
                text_unescaped: /inspect response trigger (?<trigger>.*)/
            },
            trigger: method(:inspect_trigger)

        on_event_type :slack_message,
            where: {
                addresses_me: false,
            },
            trigger: method(:slack_message)

        @data[:triggers] ||= {}
    end

    def define_trigger(args, trigger:, response:, action_phrase:)
        # determine the trigger action
        trigger_action = nil
        @@actions.each do |action, action_phrases|
            if action_phrases.include?(action_phrase)
                trigger_action = action
                break
            end
        end

        if trigger_action.nil?
            return
        end

        # strip colons from emojis
        if trigger_action == :react
            response = response.tr(':', '')
        end

        if @data[:triggers].key?(trigger)
            # trigger already exists

            # add this trigger action to actions
            unless @data[:triggers][trigger][:actions].include?(trigger_action)
                @data[:triggers][trigger][:actions] << trigger_action
            end

            # ensure this trigger action exists in responses
            @data[:triggers][trigger][:results][trigger_action] ||= []

            unless @data[:triggers][trigger][:results][trigger_action].include?(response)
                @data[:triggers][trigger][:results][trigger_action] << response
                log_info "Learned new '#{trigger_action}' action for trigger '#{trigger}': '#{response}'"
                @data.save!
            end
        else
            # trigger doesn't exist yet
            # create the trigger with this response
            @data[:triggers][trigger] = {
                actions: [trigger_action],
                results: {
                    trigger_action => [response]
                }
            }
            log_info "Learned new trigger '#{trigger}' with '#{trigger_action}' action: '#{response}'"
            @data.save!
        end
    end

    def inspect_trigger(args, trigger:)
        trigger_data = @data[:triggers][trigger]

        if trigger_data.nil?
            Spatula.helper.message(
                conversation: args[:channel],
                text: "'#{trigger}' is not a known trigger"
            )
        else
            text = "When someone says '#{trigger}', I'll perform one of the following actions: #{trigger_data[:actions].join(', ')}."
            trigger_data[:results].each do |action, responses|
                text += " '#{action}' result will be one of '#{responses.join('\', \'')}'."
            end
            Spatula.helper.message(
                conversation: args[:channel],
                text: text
            )
        end
    end

    def slack_message(**data)
        puts data.inspect
        matched_triggers = []
        @data[:triggers].each do |trigger, trigger_data|
            regex_trigger = Regexp.escape(trigger)
            regex = Regexp.union(
                # starts with
                /^#{regex_trigger}/,
                # ends with
                /#{regex_trigger}$/,
                # buffered by whitespace
                /[\s]{1,}#{regex_trigger}[\s]{1,}/
            )

            if regex.match(data[:text_unescaped])
                matched_triggers << trigger
            end
        end

        unless matched_triggers.empty?
            trigger = matched_triggers.sample
            trigger_data = @data[:triggers][trigger]
            action = trigger_data[:actions].sample
            result = trigger_data[:results][action].sample

            if action == :respond
                Spatula.helper.message(
                    conversation: data[:channel],
                    text: result
                )
            elsif action == :react
                Spatula.helper.react(
                    conversation: data[:channel],
                    timestamp: data[:ts],
                    emoji_name: result
                )
            end
        end
    end

    def unloaded

    end
end
