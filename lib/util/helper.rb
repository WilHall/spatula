require 'slack-ruby-client'
require 'pragmatic_tokenizer'
require 'json'

module Spatula
    module Util

        class SpatulaHelper
            extend Forwardable

            attr_accessor :tokenizer

            def_delegators :@rtm, :self, :team, :users, :channels, :groups, :ims, :bots

            def initialize(rtm, web)
                @rtm = rtm
                @web = web

                @tokenizer = PragmaticTokenizer::Tokenizer.new(Spatula.config.fetch(:tokenizer, {}))
            end

            def unescape(text)
                Slack::Messages::Formatting.unescape(text)
            end

            def extract_user_mentions(text)
                text.scan(/\<@(U[A-Z0-9]*)\>/).flatten
            end

            def extract_conversation_mentions(text)
                text.scan(/\<#([A-Z0-9]*)\>/).flatten
            end

            def me
                @rtm.self
            end

            def user_info(id)
                @rtm.users.fetch(id, nil)
            end

            def conversation_info(id)
                info = @rtm.channels.fetch(id, nil)

                if info.nil?
                    info = @rtm.groups.fetch(id, nil)
                end

                if info.nil?
                    info = @rtm.ims.fetch(id, nil)
                end

                return info
            end

            def user_id_to_name(id)
                @rtm.users.dig(id, :name)
            end

            def conversation_id_to_name(id)
                info = conversation_info(id)

                unless info.nil?
                    return info.fetch(:name, nil)
                end

                return nil
            end

            def message(conversation:, text:, **kwargs)
                api_args = kwargs.merge({
                    channel: conversation,
                    text: text,
                    parse: :full,
                    as_user: true
                })

                Spatula.web.chat_postMessage(**api_args)
            end

            def result_message(conversation:, text:, success:, **kwargs)
                result_emoji = (success ? ':heavy_check_mark:' : ':x:')
                message(conversation: conversation, text: "#{result_emoji} #{text}", **kwargs)
            end

            def react(conversation:, timestamp:, emoji_name:, **kwargs)
                api_args = kwargs.merge({
                    channel: conversation,
                    timestamp: timestamp,
                    name: emoji_name
                })

                Spatula.web.reactions_add(**api_args)
            end
        end

    end
end
