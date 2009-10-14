module RubyIRCd
  class Message
    attr_reader :prefix, :command, :params  
    
    def initialize(line)
      parts = line.split(' ')
      
      if parts[0][0..0] == ':'
        @prefix = parts.shift[1..-1]
      else
        @prefix = ''
      end
      
      @command = parts.shift
      
      @params = []
      until parts.empty? do
        if parts[0][0..0] == ':'
          @params << parts.join(' ')[1..-1]
          break
        else
          @params << parts.shift
        end
      end
    end
  end
end