require "active_record"
require "active_support/core_ext/object/try"
require "active_support/core_ext/class/attribute"

module Replidog
  class Proxy
    REPLICABLE_METHOD_NAMES = [/^select(?:_\w+)$/]
    REPLICABLE_METHOD_NAMES_REGEXP = /\A#{Regexp.union(REPLICABLE_METHOD_NAMES)}\z/

    attr_writer :index

    attr_reader :configuration

    def initialize(handler, configuration)
      @handler = handler
      @configuration = configuration
    end

    def current_model
      Thread.current['replidog.current_model']
    end

    def current_model=(model)
      Thread.current['replidog.current_model'] = model.is_a?(ActiveRecord::Base) ? model.class : model
    end

    def current_connection_name
      Thread.current['replidog.current_connection_name']
    end

    def current_connection_name=(connection_name)
      Thread.current['replidog.current_connection_name'] = connection_name
    end

    def transaction(options = {}, &block)
      old = current_connection_name
      self.current_connection_name ||= :master
      current_connection.transaction(options, &block)
    ensure
      self.current_connection_name = old
    end

    def connected?
      current_model.connected_without_replidog? && slave_connection_pool_table.values.any?(&:connected?)
    end

    def clear_active_slave_connections!
      slave_connection_pool_table.each_value do |pool|
        pool.release_connection
      end
    end

    def clear_reloadable_slave_connections!
      slave_connection_pool_table.each_value do |pool|
        pool.clear_reloadable_connections!
      end
    end

    def clear_all_slave_connections!
      slave_connection_pool_table.each_value do |pool|
        pool.automatic_reconnect = false
        pool.disconnect!
      end
    end

    def enable_query_cache!
      @handler.enable_query_cache!
    end

    def enable_query_cache_for_slaves!
      slave_connection_pool_table.each_value do |pool|
        pool.connection.enable_query_cache!
      end
    end

    def disable_query_cache!
      @handler.disable_query_cache!
    end

    def disable_query_cache_for_slaves!
      slave_connection_pool_table.values.each do |pool|
        pool.connection.disable_query_cache!
      end
    end

    def clear_query_cache
      @handler.clear_query_cache
    end

    def clear_query_cache_for_slaves
      slave_connection_pool_table.values.each do |pool|
        pool.connection.clear_query_cache
      end
    end

    private

    def method_missing(method_name, *args, &block)
      if current_connection_name
        current_connection.send(method_name, *args, &block)
      else
        connection_by_method_name(method_name).send(method_name, *args, &block)
      end
    end

    def respond_to_missing?(method, *args)
      master_connection.respond_to?(method, *args) || super
    end

    def connection_by_method_name(method_name)
      REPLICABLE_METHOD_NAMES_REGEXP === method_name ? slave_connection : master_connection
    end

    def current_connection
      if current_connection_name.to_s == "master"
        master_connection
      else
        slave_connection_pool_table[current_connection_name.to_s].try(:connection) or raise_connection_not_found
      end
    end

    def master_connection
      current_model.connection_without_replidog
    end

    def slave_connection
      slave_connection_pool.connection
    end

    def slave_connection_pool
      slave_connection_pool_table.values[slave_connection_index]
    end

    def replicated?
      replications
    end

    def replications
      @configuration.config[:replications] || []
    end

    def slave_connection_pool_table
      @slave_connection_pools ||= replications.inject({}) do |table, (name, configuration)|
        table.merge(name => ConnectionPoolCreater.create(configuration))
      end
    end

    def raise_connection_not_found
      raise StandardError, "connection #{current_connection_name} is not found"
    end

    def slave_connection_index
      index.tap { increment_slave_connection_index }
    end

    def increment_slave_connection_index
      self.index = (index + 1) % slave_connection_pool_table.size
    end

    def index
      @index ||= rand(slave_connection_pool_table.size)
    end

    # Creates database connection pool from configuration Hash table.
    class ConnectionPoolCreater
      def self.create(*args)
        new(*args).create
      end

      def initialize(configuration)
        @configuration = configuration.dup
      end

      def create
        spec =
          if ActiveRecord::VERSION::MAJOR >= 5 || (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR >= 1)
            ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new({}).spec(@configuration)
          elsif ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR < 1
            ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(@configuration, {}).spec
          else
            ActiveRecord::Base::ConnectionSpecification::Resolver.new(@configuration, {}).spec
          end

        ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec)
      end
    end
  end
end
