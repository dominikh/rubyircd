require 'test/unit'
require 'stringio'
require File.join(File.dirname(__FILE__), 'server_test_tools')

class BasicsTest < Test::Unit::TestCase
  
  def test_configuration
    # String config
    server = RubyIRCd::Server.new "foo 'bar'"
    assert_equal 'bar', server.configuration.foo
    
    # Proc config
    server = RubyIRCd::Server.new lambda { foo 'bar' }
    assert_equal 'bar', server.configuration.foo
    
    # direct access
    server = RubyIRCd::Server.new
    server.configuration.foo = 'bar'
    assert_equal 'bar', server.configuration.foo
    
    # sections
    server = RubyIRCd::Server.new lambda { something { foo 'bar' } }
    assert_equal 'bar', server.configuration.something.foo
    
    # multiple arguments
    server = RubyIRCd::Server.new lambda { foo 'bar1', 'bar2' }
    assert_equal ['bar1', 'bar2'], server.configuration.foo
    
    # multiple entries
    server = RubyIRCd::Server.new lambda { foo 'bar1'; foo 'bar2' }
    assert_equal ['bar1', 'bar2'], server.configuration.foo
    
    # multiple sections
    server = RubyIRCd::Server.new lambda { something { foo 'bar1' }; something { foo 'bar2' } }
    assert_equal 'bar1', server.configuration.something[0].foo
    assert_equal 'bar2', server.configuration.something[1].foo
    
    # reading in configuration
    server = RubyIRCd::Server.new lambda { foo 'bar'; foo2 foo }
    assert_equal 'bar', server.configuration.foo2
  end
  
  def test_message_parsing
    msg = RubyIRCd::Message.new(':abc DEF ghi jkl :mno')
    assert_equal 'abc', msg.prefix
    assert_equal 'DEF', msg.command
    assert_equal ['ghi', 'jkl', 'mno'], msg.params
  end
  
  def test_logging
    orig_out = $stdout
    $stdout = StringIO.new
    
    server = RubyIRCd::Server.new lambda { log_types [:test] }
    server.log :test, 'WWW'
    server.log :blub, 'XXX'
    server.log :test, 'YYY'
    
    assert_equal "[test] WWW\n[test] YYY\n", $stdout.string
  ensure
    $stdout = orig_out
  end
  
end