module MultiDb
  module ActiveRecordExtensions
    def self.included(base)
      base.send :include, InstanceMethods
      base.send :extend, ClassMethods
      base.alias_method_chain :reload, :master
      base.cattr_accessor :connection_proxy
      # handle subclasses which were defined by the framework or plugins
      base.send(:subclasses).each do |child|
        child.hijack_connection
      end
    end

    module InstanceMethods
      def reload_with_master(*args, &block)
        self.connection_proxy.with_master { reload_without_master(*args, &block) }
      end
    end

    module ClassMethods
      # Make sure transactions always switch to the master
      def transaction(options = {}, &block)
        if self.connection.kind_of?(ConnectionProxy)
          super(options)
        else
          self.connection_proxy.with_master { super(options) }
        end
      end

      # make caching always use the ConnectionProxy
      def cache(&block)
        if ActiveRecord::Base.configurations.blank?
          yield
        else
          self.connection_proxy.cache(&block)
        end
      end

      def inherited(child)
        super
        child.hijack_connection
      end

      def hijack_connection
        return if ConnectionProxy.master_models.include?(self.to_s)
        logger.info "[MULTIDB] hijacking connection for #{self.to_s}"
        class << self
          def connection
            self.connection_proxy
          end
        end
      end
    end
  end
end