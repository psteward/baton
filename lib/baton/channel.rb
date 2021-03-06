require 'baton/consumer'
require 'baton/logging'
require 'bunny'

module Baton
  class Channel
    include Baton::Logging

    attr_accessor :channel, :exchange_in, :exchange_out, :connection, :connection_options

    # Public: Initialize a Channel. It creates an AMQP connection, a channel,
    # an input exchange, and an output exchange.
    def initialize
      
      @connection_options = Baton.configuration.connection_opts

      logger.info "Connecting to AMQP host: #{@connection_options[:host]}:#{@connection_options[:port]}"

      tries = 10
      seconds_between_tries = 10
      added_seconds_between_tries = 15
      begin
        @session = Bunny.new(@connection_options)
        @session.start
      rescue Exception => e
        tries -= 1
        logger.error("#{e.class}: #{e.message}. #{tries} #{tries == 1 ? 'try' : 'tries'} remaining")
        if tries > 0
          logger.info("Trying to connect again in #{seconds_between_tries} seconds")
          sleep seconds_between_tries
          seconds_between_tries += added_seconds_between_tries
          retry
        else
          exit 1
        end
      end
            
      @channel = @session.channel

      # Not everything needs an input exchange; default to the "" exchange if there isn't
      # one defined in the config (monitors, for example)
      Baton.configuration.exchange = '' if Baton.configuration.exchange.nil?

      # Create the exchanges
      # Input exchange is how baton receives messages
      # Output exchange is how baton returns output
      @exchange_in  = channel.direct(Baton.configuration.exchange)
      if Baton.configuration.exchange_out.nil? || Baton.configuration.exchange_out.empty?
        logger.error 'An output exchange must be configured. Exiting.'
        exit 1
      else
        @exchange_out = channel.direct(Baton.configuration.exchange_out)
      end

      logger.info 'Connection to AMQP host established'
    end


    # Public: creates a consumer manager with a consumer attached and starts
    # listening to messages.
    #
    # consumer - An instance of Baton::Consumer. it will typically be a extension of
    # Baton::Consumer (e.g. Baton::DeployConsumer).
    #
    # Examples
    #
    #   add_consumer(consumer)
    #
    # Returns nothing.
    def add_consumer(consumer)
      Baton::ConsumerManager.new(consumer, @channel, @exchange_in, @exchange_out).start
    end
  end
end
