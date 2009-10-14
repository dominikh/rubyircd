module RubyIRCd
  class Plugin
    attr_reader :name, :server
  
    def initialize(name, server)
      @name = name
      @server = server
      @version = nil
    end

    def to_s
      name
    end
    
    def start
      #plugins can override this method
    end
    
    def stop
      #plugins can override this method
    end
    
    def version(value = nil)
      @version = value unless value.nil?
      @version
    end

    def method_missing(name, *args, &block)
      server.__send__(name, *args, &block)
    end

  end
end