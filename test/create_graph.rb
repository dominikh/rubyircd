require 'rubygems'
require 'ograph'
require File.join(File.dirname(__FILE__), 'server_test_tools')

include ServerTestTools

public
def assert_block(msg)
  raise msg if !yield
end

server = create_server do
  hostname    'localhost'
  port        6670
  log_types []
end

grapher = ObjectGraph.new()
grapher.graph(server) do
  client1 = create_client 6670
  client1.send_message 'NICK testuser1'
  client1.send_message 'USER testuser1 testuser1 localhost :Test User 1'
  client1.assert_response '376'
  client1.send_message 'JOIN #testchannel'
  client1.assert_response ':testuser1!testuser1@testuser1 JOIN #testchannel'
end
puts grapher
