module RubyIRCd
  class IrcError < RuntimeError
    attr_reader :error_no, :params
  
    def initialize(error_no, *params)
      @error_no = error_no
      @params = params
    end
  end
end