class ExamplePlugin

    def loaded
        log_debug "The example plugin has loaded!"

        on_event_type :slack_message,
            where: {
                addresses_me: true,
                text: /do you recall/
            },
            trigger: :recall

        on_event_type :slack_message,
            where: {
                addresses_me: true,
                text: /remember (?<thing>.*)$/
            },
            trigger: :remember
    end

    def remember(event_data, thing:)
        @data[:thing] = thing;
        @data.save!

        user_name = event_data[:user_name]
        channel = event_data[:channel]
        Spatula.helper.message(
            conversation: channel,
            text: "Okay @#{user_name}, I'll remember that."
        )
    end

    def recall(**event_data)
        user_name = event_data[:user_name]
        channel = event_data[:channel]
        thing = @data.fetch(:thing, nil)
        if thing.nil?
            Spatula.helper.message(
                conversation: channel,
                text: "@#{user_name} Hm.. no, I don't recall."
            )
        else
            Spatula.helper.message(
                conversation: channel,
                text: "@#{user_name} oh, do you mean '#{thing}'?"
            )
        end
    end

    def unloaded
        log_debug "The example plugin has unloaded."
    end

    def config_reloaded
        log_debug "The example plugin has been notified of a configuration change."
    end

end
