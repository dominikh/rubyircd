require File.expand_path(File.join(File.dirname(__FILE__), '../rubyircd.rb'))

module ServerTestTools
  
  class TestClient
    def initialize(test_case, port)
      @test_case = test_case
      @socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true) # to make mass connects fluid
      @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, [1, 0].pack("ii")) # to avoid port block (TIME_WAIT state)
      @socket.connect(Socket.sockaddr_in(port, 'localhost'))
      @buffer = []
    end
    
    def close
      @socket.close unless @socket.closed?
    end
    
    def send_message(line)
      @socket.send line + "\r\n", Socket::MSG_DONTWAIT
    end
    
    def assert_response(expected_response)
      @test_case.assert_block('Expected response not matched: "' + expected_response + '"') { look_for_response(expected_response) }
    end
    
    private
    
    def look_for_response(expected_response)
      timeout(3) do
        loop do
          @buffer.each do |line|
            if line.include? expected_response
              @buffer.delete(line)
              return true
            end
          end
          
          data = @socket.recvfrom(1024)[0]
          data.split("\n").each do |line|
            line.chomp!
            @buffer.push line
          end
        end
      end 
    end
    
    class TimeoutError < RuntimeError
    end
    
    def timeout(sec)
      begin
        x = Thread.current
        y = Thread.start do
          sleep sec
          x.raise TimeoutError.new if x.alive?
        end
        return yield(sec)
      rescue TimeoutError
        return false
      ensure
        y.kill if y and y.alive?
      end
    end
  end
  
  def close_all
    @servers.call_each.stop if @servers
    @clients.call_each.close if @clients
  end
  
  def create_server(&conf)
    server = RubyIRCd::Server.new conf
    server.start
   (@servers ||= []) << server
    server
  end
  
  def create_client(port)
    client = TestClient.new self, port
   (@clients ||= []) << client
    client
  end
  
end