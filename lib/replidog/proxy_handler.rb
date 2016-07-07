module Replidog
  class ProxyHandler
    def initialize
      @proxies = {}
      @class_to_proxy = {}
    end

    def establish_connection(configuration, klass)
      @proxies[configuration] ||= Proxy.new(self, configuration)
      @class_to_proxy[klass.name] ||= @proxies[configuration]
    end

    def retrieve_proxy(klass)
      proxy = @class_to_proxy[klass.name]
      return proxy if proxy
      return nil if ActiveRecord::Base == klass
      retrieve_proxy(klass.superclass)
    end

    def remove_connection(klass)
      proxy = @class_to_proxy.delete(klass.name)
      return nil unless proxy

      @proxies.delete(proxy.configuration)
      proxy.clear_all_slave_connections!
      proxy.configuration.config
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
