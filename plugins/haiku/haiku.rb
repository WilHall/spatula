require 'json'

class HaikuPlugin

    def loaded
        @haikumojis = [':fallen_leaf:', ':leaves:', ':peace_symbol:', ':dove_of_peace:']

        @syllable_map = JSON.parse(File.read('data/plugins/haiku/cmudict-0.7b.json'))

        on_event_type :slack_message,
            trigger: :look_for_haiku
    end

    def look_for_haiku(**event_data)
        if event_data[:text_tokenized].length > 0
            words = event_data[:text_tokenized]
            message_syllables = 0
            word_syllable_summary = ''
            word_syllables = words.collect do |word|
                word_syllables = @syllable_map.fetch(word.downcase, 0)
                message_syllables += word_syllables
                word_syllable_summary += "#{word}[#{word_syllables}] "

                word_syllables
            end

            log_info "message had #{message_syllables} syllables: #{word_syllable_summary}"

            if message_syllables == 17
                lines = []
                checkpoint = 0
                [5, 7, 5].each do |target|
                    line = []
                    syllable_sum = 0

                    words[checkpoint..-1].each_with_index do |word, i|
                        unless word.match(/^[[:alnum:]'\-]+$/)
                            next
                        end

                        unless @syllable_map.include?(word.downcase)
                            log_info "encountered unknown word '#{word}'"
                            return
                        end

                        syllables = word_syllables[checkpoint+i]
                        syllable_sum += syllables
                        line << word

                        if syllable_sum == target
                            checkpoint = checkpoint+i+1
                            lines << line.join(' ')
                            break
                        elsif syllable_sum > target
                            return # give up, no matches
                        end
                    end

                    if syllable_sum < target
                        return # give up, no matches
                    end
                end

                # woo, a haiku!
                Spatula.helper.message(
                    conversation: event_data[:channel],
                    text: "_#{lines[0]}_\n    _#{lines[1]}_\n_#{lines[2]}_\n        "+@haikumojis.sample
                )
            end
        end
    end

    def unloaded

    end

    def config_reloaded

    end

end
