require 'socket'
require 'monitor'
require 'sync'
require 'mutex_m'
require 'resolv'
require 'ident'

def require_absolute filename
  require File.expand_path(File.join(File.dirname(__FILE__), filename))
end

require_absolute 'lib/ruby_extensions'
require_absolute 'lib/configuration'
require_absolute 'lib/message'
require_absolute 'lib/irc_error'
require_absolute 'lib/constants'
require_absolute 'lib/plugin'
require_absolute 'lib/server'
require_absolute 'lib/user'
require_absolute 'lib/channel'

if $0 == __FILE__ || ARGV[0] == 'run_server' # if it is run directly or run_server argument is passed
  server = RubyIRCd::Server.new(IO.read('rubyircd.conf'))
  server.start
  server.thread.join
end
