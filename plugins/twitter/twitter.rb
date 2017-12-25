require 'twitter'

class TwitterPlugin

    def loaded
        @max_tweet_count = config.fetch(:max_tweet_count, 100)

        @client = Twitter::REST::Client.new do |client_config|
            client_config.consumer_key = config[:consumer_key]
            client_config.consumer_secret = config[:consumer_secret]
            client_config.access_token = config[:access_token]
            client_config.access_token_secret = config[:access_token_secret]
        end

        on_event_type :slack_message,
        where: {
            text: /\B(?<hashtags>#\w*[a-zA-Z]+)\w*/,
            multi: true
        },
        trigger: :hashtags
    end

    def hashtags(event_data, hashtags:)
        hashtag = hashtags.sample

        if hashtag
            tweet = @client.search(hashtag, result_type: "recent").take(@max_tweet_count).sample

            if tweet
                if tweet.media?
                    Spatula.helper.message(
                        conversation: event_data[:channel],
                        attachments: [
                            {
                                text: tweet.full_text,
                                image_url: tweet.media.media_uri
                            }
                        ]
                    )
                else
                    Spatula.helper.message(
                        conversation: event_data[:channel],
                        text: tweet.full_text
                    )
                end
            end
        end
    end

    def unloaded

    end

    def config_reloaded

    end

end
