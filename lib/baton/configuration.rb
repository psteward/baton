require "yaml"
require "baton/logging"

module Baton
  class Configuration
    include Baton::Logging

    attr_accessor :config, :host, :vhost, :user, :password, :amqp_host_list, :heartbeat

    def initialize
      @config = {}
    end

    # Public: ensure that any configuration options are automatically exposed.
    #
    def method_missing(name, *args, &block)
      if name.to_s[-1] == '='
        config[name[0..-2].to_s.upcase] = args[0]
      else
        config.fetch(name.to_s.upcase) {nil}
      end
    end

    # Public: Loads the config file given as parameter and sets up RabbitMQ's options.
    #
    # path - A file path representing a config file
    #
    # Examples
    #
    #   config_file = "/path/to/file"
    #
    # Returns nothing.
    # Raises Errno::ENOENT if file cannot be found.
    def config_path=(path)
      config_file = YAML.load_file(path)
      config.merge!(config_file)
      setup_rabbitmq_opts
    rescue Errno::ENOENT => e
      self.host = "localhost"
      logger.error "Could not find a baton configuration file at #{path}"
    end

    # Public: Setup RabbitMQ's options from a config file. You have the option of 
    # passing in a comma seperated string of RabbitMQ servers to connect to. When 
    # using a pool of servers one will be randomly picked for the initial connection. 
    #
    # config_file - A hash representing a config file
    #
    # Examples
    #
    #   # Single RabbitMQ server
    #   config = {
    #     "RABBIT_HOST" => "localhost",
    #     "RABBIT_VHOST" => "baton",
    #     "RABBIT_USER" => "baton",
    #     "RABBIT_PASS" => "password"
    #     }
    #
    #   # Use a pool of RabbitMQ servers
    #   config = {
    #     "RABBIT_HOST" => "host1,host2,host3",
    #     "RABBIT_VHOST" => "baton",
    #     "RABBIT_USER" => "baton",
    #     "RABBIT_PASS" => "password"
    #     }
    #
    #   setup_rabbitmq_opts
    #
    # Returns nothing.
    def setup_rabbitmq_opts

      rabbit_hosts    = config.fetch("RABBIT_HOST") {"localhost"}
      rabbit_hosts    = rabbit_hosts.split(',')

      # Pick a random host to connect to
      self.host      = rabbit_hosts[Kernel.rand(rabbit_hosts.size)]
      self.amqp_host_list = rabbit_hosts
      self.port      = config["RABBIT_PORT"]

      self.vhost     = config["RABBIT_VHOST"]
      self.user      = config["RABBIT_USER"]
      self.password  = config["RABBIT_PASS"]
      self.heartbeat = config.fetch("RABBIT_HEARTBEAT", 60).to_i

      # Must be a complete certificate chain, from server cert to root cert, in PEM format
      self.ssl_cert  = config["SSL_CERTIFICATE_CHAIN"]
      self.ssl_key   = config["SSL_KEY"]
      self.verify_peer? = config["VERIFY_PEER"]
      # Options include: SSLv23, SSLv3, and TLSv1
      self.ssl_version = config["SSL_VERSION"]
    end

    # Public: Defines the connection options for RabbitMQ as a Hash.
    #
    # Examples
    #
    #   connection_options
    #   # => {:host=>"localhost", :vhost=>"baton", :user=>"baton", :password=>"password"}
    #
    # Returns a hash of RabbitMQ connection options.
    def connection_opts
      {
        :host => host, 
        :port => port,
        :vhost => vhost, 
        :user => user, 
        :password => password, 
        :pass => password,
        :heartbeat => heartbeat,
        :ssl => {
          :cert_chain_file => ssl_cert,
          :private_key_file => ssl_key,
          :verify_peer => verify_peer?,
          :ssl_version => ssl_version
        }
      }.delete_if{|k,v| v.nil?}
    end
  end
end
