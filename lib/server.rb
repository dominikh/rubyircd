module RubyIRCd
  class Server
    attr_accessor :configuration, :port, :thread

    def initialize(config=nil)
      @configuration = Configuration.new
      @configuration.evaluate_config config

      @configuration.port ||= 6667
      @configuration.plugin_path ||= 'plugins-enabled'
      @configuration.log_types ||= [:info, :warning, :error]
      @configuration.log_prefix ||= ''

      @thread = nil;
      @tcpserver = nil
      @users = []
      @channels = SynchronizableHash.new
      @nicknames = SynchronizableHash.new

      @modes = {}
      #global modes for users, like +x (hide hostmask)
      register_mode :global, 'x'
      #modes for users in a channel, like +o (operator)
      register_mode :user, 'o'
      register_mode :user, 'v'
      #modes for a channel, like +n (no external messages)
      register_mode :channel, 'n'
      register_mode :channel_parameterized, 'k'

      @all_plugins = []
      @categorized_plugins = {}
      @command_plugins = {}
    end

    def start # blubb
      load_plugins
      open_socket
      @thread = Thread.new do
        accept_users
      end
    end

    def stop
      @thread.raise Interrupt.new
      @thread.join
    end

    def load_plugins
      @configuration.plugin_path.to_a.each do |path|
        Dir.glob(File.join(File.expand_path(path, File.dirname(__FILE__)), '*.rb')) do |file|
          plugin = Plugin.new(File.basename(file, '.rb'), self)
          SCRIPT_LINES__[file] = IO.readlines(file) if defined? SCRIPT_LINES__ # to make rcov able to analyze plugins
          plugin.instance_eval IO.read(file), file
          if plugin.version.nil?
            log :error, "You must specify a version for plugin \"#{plugin.name}\"."
            next
          end

          @all_plugins << plugin
          plugin.singleton_methods.each do |method_name|
            if method_name[-8..-1] == '_command'
              command = method_name[0..-9]
              log :error, "Plugin conflict." if !@command_plugins[command].nil? # TODO better error message
              @command_plugins[command] = plugin
            else
             (@categorized_plugins[method_name.to_sym] ||= []) << plugin
            end
          end
        end
      end

      log :info, "Plugins loaded: #{@all_plugins.join(', ')}"
    end

    def plugins_for(category)
      @categorized_plugins[category] || []
    end

    def plugin_command(msg)
      plugin = @command_plugins[msg.command.downcase]
      return false if plugin.nil?
      plugin.__send__("#{msg.command.downcase}_command", *msg.params)
    end

    def log(log_type, message)
      if @configuration.log_types.include? log_type
        print "#{@configuration.log_prefix}[#{log_type.to_s}] #{message}\n"
      end
    end

    def hostname
      @configuration.hostname
    end

    def register_mode(type, mode)
      log :debug, "Mode registered: #{type} #{mode}"
      @modes[mode] = type
    end

    def mode_type(mode)
      @modes[mode]
    end

    def open_socket
      @tcpserver = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      @tcpserver.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, true) # to make mass connects fluid
      @tcpserver.setsockopt(Socket::SOL_SOCKET, Socket::SO_LINGER, [1, 0].pack("ii")) if @configuration.debug # to avoid port block (TIME_WAIT state)
      @tcpserver.bind(Socket.pack_sockaddr_in(@configuration.port, ''))
      @tcpserver.listen(1024)
    end

    def accept_users
      @all_plugins.call_each.start
      cur_id = 0
      loop do
        Thread.start(@tcpserver.accept[0], cur_id) do |socket, user_id|
          user = nil
          begin
            user = User.new(self, socket, user_id)
            @users << user
            user.listen
          rescue Exception => e
            return if user.quitting?
            log :error, "#{user_id}: Session crashed - #{e.message} (#{e.class})\n#{e.backtrace.join("\n")}\n"
            user.quit "Session crashed"
          end
          @users.delete(user)
          @nicknames.delete(user.nickname.downcase)
        end
        cur_id += 1
      end
    rescue Interrupt, SystemExit
      @users.call_each.quit 'server shutdown'
      @all_plugins.call_each.stop
      @tcpserver.close
      log :info, 'Bye!'
    end

    def create_channel(name)
      @channels.synchronize do
        @channels[name.downcase] = Channel.new(self, name) unless @channels.has_key?(name.downcase)
      end
    end

    def get_channel(name)
      @channels[name.downcase]
    end

    def get_user(nickname)
      @nicknames[nickname.downcase]
    end

    def request_nickname_change(user, new_nickname)
      @nicknames.synchronize do
        raise IrcError.new(nil) if user.nickname == new_nickname

        if @nicknames.has_key?(new_nickname.downcase)
          unless user.nickname and (user.nickname.downcase != new_nickname.downcase)
            raise IrcError.new(ERR_NICKNAMEINUSE, "#{new_nickname} :Nickname is already in use")
          end
        end

        plugins_for(:pre_nickname_change).call_each.pre_nickname_change(user, new_nickname)

        if !user.nickname.nil?
          @nicknames.delete(user.nickname.downcase)
          user.connected_users.each do |on_server|
            on_server.send_message ":#{user.nickname}!#{user.username}@#{user.hostname}", "NICK", ":#{new_nickname}"
          end
        end

        @nicknames[new_nickname.downcase] = user
        user.nickname = new_nickname
      end
    end
  end
end
