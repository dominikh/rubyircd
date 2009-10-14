module RubyIRCd
  class Configuration
    class EvaluateConfigContext
      def initialize(configuration)
        @configuration = configuration
      end
      
      def method_missing(name, *values, &block)
        name = name.to_s[0..-2].to_sym if name.to_s[-1..-1] == '='
        
        if !block.nil?
          subconf = Configuration.new
          subconf.evaluate_config block
          values = [subconf]
        else
          if values.size == 0
            return @configuration.__send__(name)
          end
        end
        
        values.each do |value|
          cur_value = @configuration.__send__(name)
          if cur_value.nil?
            @configuration.__send__("#{name}=", value)
          else
            if !cur_value.is_a?(Array)
              @configuration.__send__("#{name}=", [cur_value])
            end
            @configuration.__send__(name) << value
          end
        end
      end
    end
    
    def method_missing(name, *args, &block)
      name = name.to_s[0..-2].to_sym if name.to_s[-1..-1] == '='
      self.class.class_eval { attr_accessor name }
      __send__(name, *args, &block)
    end
    
    def evaluate_config(config)
      if config.is_a? String
        EvaluateConfigContext.new(self).instance_eval(config)
      elsif config.is_a? Proc
        EvaluateConfigContext.new(self).instance_eval(&config)
      end
    end
  end
end