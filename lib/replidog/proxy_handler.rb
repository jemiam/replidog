require "concurrent/map"

module Replidog
  class ProxyHandler
    def initialize
      @proxies = Concurrent::Map.new(initial_capacity: 2)
      @class_to_proxy = Concurrent::Map.new(initial_capacity: 2)
    end

    def establish_connection(configuration, klass)
      @class_to_proxy.clear
      raise RuntimeError, "Anonymous class is not allowed." unless klass.name
      @proxies[klass.name] = Proxy.new(self, configuration)
    end

    def retrieve_proxy(klass)
      @class_to_proxy[klass.name] ||=
        begin
          until proxy = @proxies[klass.name]
            klass = klass.superclass
            break unless klass <= ActiveRecord::Base
          end

          @class_to_proxy[klass.name] = proxy
        end
    end

    def remove_connection(klass)
      if proxy = @proxies.delete(klass.name)
        @class_to_proxy.clear
        proxy.clear_all_slave_connections!
        proxy.configuration.config
      end
    end

    def clear_active_slave_connections!
      @proxies.each_value do |proxy|
        proxy.clear_active_slave_connections!
      end
    end

    def clear_reloadable_slave_connections!
      @proxies.each_value do |proxy|
        proxy.clear_reloadable_slave_connections!
      end
    end

    def clear_all_slave_connections!
      @proxies.each_value do |proxy|
        proxy.clear_all_slave_connections!
      end
    end

    def enable_query_cache!
      connection_pool_list_for(ActiveRecord::Base.connection_handler).each do |connection_pool|
        connection_pool.connection.enable_query_cache!
      end
      @proxies.each_value(&:enable_query_cache_for_slaves!)
    end

    def disable_query_cache!
      connection_pool_list_for(ActiveRecord::Base.connection_handler).each do |connection_pool|
        connection_pool.connection.disable_query_cache!
      end
      @proxies.each_value(&:disable_query_cache_for_slaves!)
    end

    def clear_query_cache
      connection_pool_list_for(ActiveRecord::Base.connection_handler).each do |connection_pool|
        connection_pool.connection.clear_query_cache
      end
      @proxies.each_value(&:clear_query_cache_for_slaves)
    end

    private

    def connection_pool_list_for(connection_handler)
      if ActiveRecord::VERSION::MAJOR >= 4
        connection_handler.connection_pool_list
      else
        connection_handler.connection_pools.values
      end
    end
  end
end
