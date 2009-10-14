require 'test/unit'
require File.join(File.dirname(__FILE__), 'server_test_tools')

class BasicsTest < Test::Unit::TestCase
  include ServerTestTools
  
  # @server1.configuration.log_types = [:debug, :error]
  
  def setup
    @server1 = create_server do
      hostname    'localhost'
      port        6670
      plugin_path File.expand_path('test_plugins', File.dirname(__FILE__)), File.expand_path('../lib/plugins-enabled', File.dirname(__FILE__))
      log_types   []
      log_prefix  '{1} '
      debug       true
      
      linked_server do
        name 'server2'
        host 'localhost'
        port '6671'
        my_password 'password1'
        its_password 'password2'
      end
    end
    
    @server2 = create_server do
      hostname    'localhost'
      port        6671
      plugin_path File.expand_path('test_plugins', File.dirname(__FILE__)), File.expand_path('../lib/plugins-enabled', File.dirname(__FILE__))
      log_types   []
      log_prefix  '{2} '
      debug       true
      
      linked_server do
        name 'server1'
        host 'localhost'
        port '6670'
        my_password 'password2'
        its_password 'password1'
      end
    end
    
    @client1 = create_client 6670
    @client1.send_message 'NICK testuser1'
    @client1.send_message 'USER testuser1 testuser1 localhost :Test User 1'
    @client1.assert_response '376'
    @client1.send_message 'JOIN #testchannel'
    @client1.assert_response ':testuser1!testuser1@testuser1 JOIN #testchannel'
    
    @client2 = create_client 6671
    @client2.send_message 'NICK testuser2'
    @client2.send_message 'USER testuser2 testuser2 localhost :Test User 2'
    @client2.assert_response '376'
    @client2.send_message 'JOIN #testchannel'
    @client2.assert_response ':testuser2!testuser2@testuser2 JOIN #testchannel'
  end
  
  def teardown
    close_all
  end
  
  #  def test_login_and_join
  #    client3 = create_client 6670
  #    
  #    client3.send_message 'NICK testuser3'
  #    client3.send_message 'USER testuser3 testuser3 localhost :Test User'
  #    client3.assert_response ':localhost 001 testuser3 :Welcome on this RubyIRCd server, testuser3' # welcome message
  #    
  #    @client1.send_message 'JOIN #testchannel' # ignored
  #    
  #    client3.send_message 'JOIN #testchannel'
  #    client3.assert_response ':testuser3!testuser3@testuser3 JOIN #testchannel' # confirmation
  #    client3.assert_response ':localhost 332 testuser3 #testchannel :BWAAAAAAAAAAAAAAAAAA!' # topic
  #    client3.assert_response ':localhost 353 testuser3 = #testchannel :@testuser1 testuser2 testuser3' # user list
  #    client3.assert_response ':localhost 366 testuser3 #testchannel :End of /NAMES list'
  #    
  #    @client1.assert_response ':testuser3!testuser3@testuser3 JOIN #testchannel' # inform other clients
  #  end
  #  
  #  def test_mode_and_userlist
  #    client3 = create_client 6670
  #    client3.send_message 'NICK testuser3'
  #    client3.send_message 'USER testuser3 testuser3 localhost :Test User'
  #    client3.assert_response '376'
  #    client3.send_message 'JOIN #testchannel2'
  #    
  #    @client1.send_message 'MODE #testchannel +v testuser2'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel +v testuser2'
  #    @client2.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel +v testuser2'
  #    
  #    client3.send_message 'JOIN #testchannel'    
  #    client3.assert_response ':localhost 353 testuser3 = #testchannel :@testuser1 +testuser2 testuser3'
  #    
  #    @client1.send_message 'MODE #testchannel -v testuser2'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel -v testuser2'
  #    @client2.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel -v testuser2'
  #    
  #    @client1.send_message 'MODE #testchannel +k anykey'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel +k anykey'
  #    @client2.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel +k anykey'
  #    
  #    @client1.send_message 'MODE #testchannel2 +v testuser2'
  #    @client1.assert_response ':localhost 442 testuser1 #testchannel2 :You\'re not on that channel'
  #    @client2.send_message 'MODE #testchannel +o testuser2'
  #    @client2.assert_response ':localhost 482 testuser2 #testchannel :You\'re not channel operator'
  #    
  #    @client1.send_message 'MODE #testchannel +ov testuser2'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel +ov testuser2'
  #    
  #    @client1.send_message 'MODE #testchannel +vvo testuser1 testuser3'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel +vv testuser1 testuser3'
  #  end
  #  
  #  def test_server_password
  #    @server1.configuration.server_password = 'thesecretpassword'
  #    
  #    client3 = create_client 6670
  #    client3.send_message 'PASS donotknow'
  #    client3.send_message 'NICK testuser3'
  #    client3.send_message 'USER testuser3 testuser3 localhost :Test User'
  #    client3.assert_response ':localhost 464 testuser3 :Password incorrect' # ERR_PASSWDMISMATCH rejection
  #    
  #    client4 = create_client 6670
  #    client4.send_message 'PASS thesecretpassword'
  #    client4.send_message 'NICK testuser4'
  #    client4.send_message 'USER testuser4 testuser4 localhost :Test User'
  #    client4.assert_response '376'
  #  end
  #  
  #  def test_not_registered
  #    client3 = create_client 6670
  #    client3.send_message 'JOIN #abc'
  #    client3.assert_response ':localhost 451 * :You have not registered' # ERR_NOTREGISTERED rejection
  #  end
  #  
  #  def test_nick
  #    @client1.send_message 'NICK testuser1' # ignored
  #    
  #    @client1.send_message 'NICK testuser2'
  #    @client1.assert_response ':localhost 433 testuser1 testuser2 :Nickname is already in use' # ERR_NICKNAMEINUSE rejection
  #    
  #    @client1.send_message 'NICK testuser1_b'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 NICK :testuser1_b' # confirmation
  #    @client2.assert_response ':testuser1!testuser1@testuser1 NICK :testuser1_b' # inform other clients
  #  end
  #  
  #  def test_topic
  #    @client1.send_message 'TOPIC #testchannel'
  #    @client1.assert_response ':localhost 332 testuser1 #testchannel :BWAAAAAAAAAAAAAAAAAA!' # RPL_TOPIC
  #    
  #    #TODO test for RPL_NOTOPIC
  #  end
  #  
  #  def test_part
  #    @client1.send_message 'PART #nonexistingchannel :huh?'
  #    @client1.assert_response ':localhost 403 testuser1 #nonexistingchannel :No such channel' # ERR_NOSUCHCHANNEL rejection
  #    
  #    @client1.send_message 'PART #testchannel :Bye bye!'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 PART #testchannel :Bye bye!' # confirmation
  #    @client2.assert_response ':testuser1!testuser1@testuser1 PART #testchannel :Bye bye!' # inform other clients
  #    
  #    @client1.send_message 'PART #testchannel :again?'
  #    @client1.assert_response ':localhost 442 testuser1 #testchannel :You\'re not on that channel' # ERR_NOTONCHANNEL rejection
  #  end
  #  
  #  def test_channel_privmsg
  #    @client1.send_message 'PRIVMSG #nochannel :trash'
  #    @client1.assert_response ':localhost 401 testuser1 #nochannel :No such nick/channel' # ERR_NOSUCHNICK rejection
  #    
  #    @client1.send_message 'PRIVMSG #testchannel :something senseless'
  #    @client2.assert_response ':testuser1!testuser1@testuser1 PRIVMSG #testchannel :something senseless'
  #  end
  #  
  #  def test_channel_notice
  #    @client1.send_message 'NOTICE #nochannel :trash'
  #    
  #    @client1.send_message 'NOTICE #testchannel :something senseless'
  #    @client2.assert_response ':testuser1!testuser1@testuser1 NOTICE #testchannel :something senseless'
  #  end
  #  
  #  def test_user_privmsg
  #    @client1.send_message 'PRIVMSG noone :huh'
  #    @client1.assert_response ':localhost 401 testuser1 noone :No such nick/channel' # ERR_NOSUCHNICK rejection
  #    
  #    @client1.send_message 'PRIVMSG testuser2 :hello there'
  #    @client2.assert_response ':testuser1!testuser1@testuser1 PRIVMSG testuser2 :hello there'
  #  end
  #  
  #  def test_quit
  #    @client1.send_message 'QUIT :on the run'
  #    @client2.assert_response ':testuser1!testuser1@testuser1 QUIT :Quit: on the run'
  #  end
  #  
  #  def test_connection_close
  #    @client1.close
  #    @client2.assert_response ':testuser1!testuser1@testuser1 QUIT :EOF from client'
  #  end
  #  
  #  def test_session_crash
  #    @client1.send_message 'CRASH' # see test_plugins/crash_test.rb
  #    @client2.assert_response ':testuser1!testuser1@testuser1 QUIT :Session crashed'
  #  end
  #  
  #  def test_ping
  #    @client1.send_message 'PING ABCXYZ'
  #    @client1.assert_response ':localhost PONG localhost :ABCXYZ'
  #  end
  #  
  #  def test_unknown_command
  #    @client1.send_message 'SELFDESTRUCT_NOW'
  #    @client1.assert_response ':localhost 421 testuser1 SELFDESTRUCT_NOW :Unknown command' # ERR_UNKNOWNCOMMAND rejection
  #  end
  #  
  #  def test_not_enough_parameters_check
  #    @client1.send_message 'JOIN'
  #    @client1.assert_response ':localhost 461 testuser1 JOIN :Not enough parameters' # ERR_NEEDMOREPARAMS rejection
  #  end
  #  
  #  def test_channel_key
  #    @client2.send_message 'PART #testchannel'
  #    @client1.send_message 'MODE #testchannel +k thekey'
  #    @client1.assert_response ':testuser1!testuser1@testuser1 MODE #testchannel +k thekey'
  #    
  #    @client2.send_message 'JOIN #testchannel'
  #    @client2.assert_response ':localhost 475 testuser2 #testchannel :Cannot join channel (+k)' # ERR_BADCHANNELKEY rejection
  #    
  #    @client2.send_message 'JOIN #testchannel xyz'
  #    @client2.assert_response ':localhost 475 testuser2 #testchannel :Cannot join channel (+k)' # ERR_BADCHANNELKEY rejection
  #    
  #    @client2.send_message 'JOIN #testchannel thekey'
  #    @client2.assert_response ':testuser2!testuser2@testuser2 JOIN #testchannel'
  #  end
  
end