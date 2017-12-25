class PeerPressurePlugin

    def loaded
        @peer_pressure_threshold = config.fetch(:threshold, 2)

        on_event_type :slack_reaction_added, trigger: :react
    end

    def react(**event_data)
        type = event_data.dig(:item, :type).to_sym
        reaction_args = case type
        when :message
            {
                channel: event_data.dig(:item, :channel),
                timestamp: event_data.dig(:item, :ts)
            }
        when :file
            {
                file: event_data.dig(:item, :file)
            }
        when :file_comment
            {
                file_comment: event_data.dig(:item, :file_comment)
            }
        end

        me_id = Spatula.helper.me[:id]
        response = Spatula.helper.get_reactions(**reaction_args)
        response.dig(type, :reactions).each do |reaction|
            if reaction[:count] >= @peer_pressure_threshold
                unless reaction[:users].include? me_id
                    Spatula.helper.react(emoji_name: reaction[:name], **reaction_args)
                end
            end
        end
    end

    def unloaded

    end

    def config_reloaded

    end

end
