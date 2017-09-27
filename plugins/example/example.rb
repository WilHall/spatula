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

    def remember(args, thing:)
        @data[:thing] = thing;
        @data.save!

        user_name = args[:user_name]
        channel = args[:channel]
        Spatula.helper.message(
            conversation: channel,
            text: "Okay @#{user_name}, I'll remember that."
        )
    end

    def recall(**kwargs)
        user_name = kwargs[:user_name]
        channel = kwargs[:channel]
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
