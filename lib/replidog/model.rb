require "active_support/core_ext/module/aliasing"
require "active_support/core_ext/class/attribute"

module Replidog
  module Model
    def self.extended(base)
      base.class_attribute :proxy_handler, instance_writer: false
      base.proxy_handler = Replidog::ProxyHandler.new

      class << base
        alias_method :connected_without_replidog?, :connected?
        alias_method :connection_without_replidog, :connection

        prepend BaseWithReplidogSupport
      end
    end

    module BaseWithReplidogSupport
      def establish_connection(spec = ENV["DATABASE_URL"])
        super
        proxy_handler.remove_connection(self)
        proxy_handler.establish_connection(connection_pool.spec, self)
      end

      def connection
        if replicated?
          proxy_handler.retrieve_proxy(self).tap do |proxy|
            proxy.current_model = self
          end
        else
          super
        end
      end

      def connected?
        if replicated?
          connection.connected?
        else
          super
        end
      end

      def clear_active_connections!
        super
        proxy_handler.clear_active_slave_connections! if replicated?
      end

      def clear_reloadable_connections!
        super
        proxy_handler.clear_reloadable_slave_connections! if replicated?
      end

      def clear_all_connections!
        super
        proxy_handler.clear_all_slave_connections! if replicated?
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
