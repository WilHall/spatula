require 'http'
require 'nokogiri'

class WikihowPlugin

    def loaded
        @wikihow_chance = config.fetch(:chance, 1)

        on_event_type :slack_message,
            where: {
                addresses_me: false,
            },
            trigger: :chance_to_reply
        on_event_type :slack_message,
            where: {
                addresses_me: true,
                text: /wikihow/
            },
            trigger: :reply
    end

    def chance_to_reply(**event_data)
        if Random.rand(100) <= @wikihow_chance
            reply(**event_data)
        end
    end

    def reply(**event_data)
        redirect = HTTP.get('https://www.wikihow.com/Special:Randomizer')
        article = redirect[:location]

        html = HTTP.get(article).body.to_s
        doc = Nokogiri::HTML(html)
        images = doc.css('img.whcdn.content-fill').collect do |img|
            img['data-src']
        end

        images = images.compact

        Spatula.helper.message(
            conversation: event_data[:channel],
            attachments: [
                {
                    text: ":book:",
                    image_url: images.sample
                }
            ]
        )
    end

    def unloaded

    end

    def config_reloaded

    end

end
