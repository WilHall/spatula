require 'slack-ruby-client'
require 'fileutils'

require_relative 'lib/util/extensions'
require_relative 'lib/util/config'
require_relative 'lib/util/logging'
require_relative 'lib/util/helper'
require_relative 'lib/event/dispatcher'
require_relative 'lib/plugin/manager'
require_relative 'lib/message/preprocessor'

module Spatula

    # The Spatula module has some properties that are intentionally public for use as globals
    class << self
        attr_accessor :config, :logger, :web, :rtm, :dispatcher, :plugin_manager, :helper
    end

    # load main spatula configuration file
    @config = Spatula::Util::Config.new('config/spatula.yml')

    # configure the logger
    log_filename = "log/spatula.log"
    FileUtils.mkdir_p('log')
    @logger = Spatula::Util::Logger.new(log_filename)
    @logger.level = Logger.const_get(@config[:logger].fetch(:level, 'DEBUG'))

    # initialize the event dispatcher and dispatch an event when
    # the spatula configuration changes
    @dispatcher = Spatula::EventDispatcher.new
    @config.on_change {
        # when the main config changes, dispatch this as an event
        Spatula.dispatcher.event :config_changed
    }

    # configure slack global settings
    Slack.configure do |client_config|
        client_config.token = @config[:client][:token]
    end

    # configure slack rtm settings
    Slack::RealTime::Client.config do |rtm_config|
        client_logger = Logger.new(File.new("log/slack_rtm.log", 'a'))
        client_logger.level = @logger.level
        client_config.logger = client_logger
    end

    # configure slack web settings
    Slack::Web::Client.config do |web_config|
        client_config.web_config @config[:client][:user_agent]

        client_logger = Logger.new(File.new("log/slack_web.log", 'a'))
        client_logger.level = @logger.level
        client_config.logger = client_logger
    end

    # define a method which will be called whenever a slack event happens
    def on_slack_event(data)
        unless data[:user] == Spatula.helper.me[:id]
            data = @message_preprocessor.process(data)
            Spatula.dispatcher.event "slack_#{data[:type]}".to_sym, **data
        end
    end
    module_function :on_slack_event

    # create slack client, bind all known event types, and start listening
    @rtm = Slack::RealTime::Client.new
    @web = @rtm.web_client
    @helper = Spatula::Util::SpatulaHelper.new(@rtm, @web)
    @plugin_manager = Spatula::PluginManager.new
    @message_preprocessor = MessagePreprocessor.new
    @message_preprocessor.event_types.fetch(:slack, {}).keys.each do |event_type|
        @rtm.on event_type, &method(:on_slack_event)
    end

    @rtm.start!
end
