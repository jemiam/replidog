require "active_support/core_ext/module/aliasing"
require "active_support/core_ext/class/attribute"

module Replidog
  module Model
    def self.extended(base)
      base.class_attribute :proxy_handler, instance_writer: false
      base.proxy_handler = Replidog::ProxyHandler.new

      class << base
        alias_method_chain(:establish_connection, :replidog)
        alias_method_chain(:connection, :replidog)
        alias_method_chain(:connected?, :replidog)
        alias_method_chain(:clear_reloadable_connections!, :replidog)
        alias_method_chain(:clear_active_connections!, :replidog)
        alias_method_chain(:clear_all_connections!, :replidog)
      end
    end

    def establish_connection_with_replidog(spec = ENV["DATABASE_URL"])
      establish_connection_without_replidog(spec)
      proxy_handler.remove_connection(self)
      proxy_handler.establish_connection(connection_pool.spec, self)
    end

    def connection_with_replidog
      if replicated?
        proxy_handler.retrieve_proxy(self).tap do |proxy|
          proxy.current_model = self
        end
      else
        connection_without_replidog
      end
    end

    def replicated?
      connection_config[:replications].present?
    end

    def using(connection_name, &block)
      if replicated?
        _using(connection_name, &block)
      else
        if block_given?
          yield
        else
          self
        end
      end
    end

    def connected_with_replidog?
      if replicated?
        connection.connected?
      else
        connected_without_replidog?
      end
    end

    def clear_active_connections_with_replidog!
      clear_active_connections_without_replidog!
      proxy_handler.clear_active_slave_connections! if replicated?
    end

    def clear_reloadable_connections_with_replidog!
      clear_reloadable_connections_without_replidog!
      proxy_handler.clear_reloadable_slave_connections! if replicated?
    end

    def clear_all_connections_with_replidog!
      clear_all_connections_without_replidog!
      proxy_handler.clear_all_slave_connections! if replicated?
    end

    private

    def _using(connection_name)
      if block_given?
        connection.current_connection_name = connection_name
        yield
      else
        ScopeProxy.new(klass: self, connection_name: connection_name)
      end
    ensure
      connection.current_connection_name = nil if block_given?
    end

  end
end
