require_relative '../util/extensions'
require_relative '../util/config'

module Spatula

    class MessagePreprocessor

        attr_accessor :event_types

        def initialize()
            @event_types = Spatula::Util::Config.new('config/event_types.yml')
        end

        def process(data)
            # translate message data into a hash and symbolize the keys
            data = data.to_h
            data.recursive_symbolize_keys!

            # symbolize the event type, too
            data[:type] = data[:type].to_sym

            # does the message directly address me?
            in_direct_message = (data.key?(:channel) and data[:channel][0] == 'D')
            mentions_me_at_start = (data.key?(:text) and data[:text].index("<@#{Spatula.helper.me[:id]}>") == 0)
            data[:addresses_me] = (in_direct_message or mentions_me_at_start)

            # different types of pre-processing can be enabled on a per-event-type basis
            # and configured to operate on one or more data keys of the event
            # so we need to map these dynamically
            # ...
            # if there is a definition for this event type
            if @event_types[:slack].key?(data[:type])
                event_type = @event_types.dig(:slack, data[:type])

                # merge preprocess config for event, and for its subtype (if present)
                preprocess_config = event_type.fetch(:preprocess, {})
                if data.key?(:subtype)
                    subtype_preprocess_config = event_type.dig(:subtypes, data[:subtype], :preprocess)
                    if subtype_preprocess_config == false
                        # overridden by subtype to disable
                        preprocess_config = {}
                    elsif not subtype_preprocess_config.nil?
                        preprocess_config.merge!(subtype_preprocess_config)
                    end
                end

                # and it has preprocessors defined
                unless preprocess_config.empty?
                   preprocess_config.each do |data_key, preprocessors|
                        next if preprocessors == false # overridden by subtype to disable

                        preprocessors.each do |preprocessor, should_apply|
                            next unless should_apply # processor value set to false

                            if data.key?(data_key)
                                data = send("preprocess_#{preprocessor}", data_key, data)
                            end
                        end
                    end
                end
            end

            return data
        end

        private

        def preprocess_conversation_id(key, data)
            # TODO: implement
            return data
        end

        def preprocess_conversation_name(key, data)
            conversation_name_key = "#{key}_name".to_sym
            data[conversation_name_key] = Spatula.helper.conversation_id_to_name(data[key])

            return data
        end

        def preprocess_user_name(key, data)
            user_name_key = "#{key}_name".to_sym
            data[user_name_key] = Spatula.helper.user_id_to_name(data[key])

            return data
        end

        def preprocess_tokenize(key, data)
            tokenized = Spatula.helper.tokenizer.tokenize(data[key])
            tokenized_key = "#{key}_tokenized".to_sym
            data[tokenized_key] = tokenized

            return data
        end

        def preprocess_syllabify(key, data)
            # TODO: implement
            return data
        end

        def preprocess_mentions(key, data)
            mentions_me_key = tokenized_key = "#{key}_mentions_me".to_sym
            user_mentions_key = tokenized_key = "#{key}_user_mentions".to_sym
            conversation_mentions_key = tokenized_key = "#{key}_conversation_mentions".to_sym
            data[user_mentions_key] = Spatula.helper.extract_user_mentions(data[key])
            data[conversation_mentions_key] = Spatula.helper.extract_conversation_mentions(data[key])
            data[mentions_me_key] = data[user_mentions_key].include?(Spatula.helper.me[:id])

            return data
        end

        def preprocess_unescape(key, data)
            unescaped = Spatula.helper.unescape(data[key])
            unescaped_key = "#{key}_unescaped".to_sym
            data[unescaped_key] = unescaped

            return data
        end
    end

end
