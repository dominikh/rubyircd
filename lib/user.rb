module RubyIRCd
  class User
    attr_reader :channels
    attr_accessor :nickname, :username, :hostname, :password

    def initialize(server, socket, id)
      @server = server
      @socket = socket
      @id = id
      @listen_thread = nil
      @message_buffer = []
      @send_queue = []
      @password = nil
      @username = nil
      @servername = nil
      @realname = nil
      @nickname = nil
      @registered = false
      @channels = {}
      @quitting = false
      @valid_ident = false

      # NOTICE AUTH :*** Looking up your hostname...
      # NOTICE AUTH :*** Checking ident
      # NOTICE AUTH :*** No identd (auth) response
      # NOTICE AUTH :*** Found your hostname

      header = ["NOTICE", "AUTH", ":***"]
      port, ip = Socket.unpack_sockaddr_in(socket.getpeername)

      send_message(header + ["Looking up your hostname..."])
      @hostname = Resolv.getname(ip)
      send_message(header + ["Found your hostname"])

      send_message(header + ["Checking ident"])
      begin
        r = Ident.request(ip, port, @server.configuration.port)
        if r.userid
          @username = r.userid
          send_message(header + ["Got ident response"])
          @valid_ident = true
        end
      rescue Timeout::Error, Errno::ECONNREFUSED => e
        send_message(header + ["No identd (auth) response"])
      end
    end

    def quitting?
      @quitting
    end

    def listen
      debug_print 'Session opened'
      @listen_thread = Thread.current

      catch :quit_next_message_loop do
        loop do
          msg = get_next_message
          if !msg
            quit 'EOF from client'
            throw :quit_next_message_loop
          end

          begin
            if !@registered && !['QUIT', 'PASS', 'USER', 'NICK'].include?(msg.command.upcase)
              raise IrcError.new(ERR_NOTREGISTERED, ':You have not registered')
            end

            if self.respond_to? msg.command.downcase + "_command"
              command_method = method(msg.command.downcase + "_command")
              arity = command_method.arity
              # arity = ~arity if arity < 0
              min_arity = if arity < 0
                            ~arity
                          else
                            arity
                          end

              if min_arity-1 > msg.params.size
                raise IrcError.new(ERR_NEEDMOREPARAMS, msg.command, ':Not enough parameters')
              end

              # drop any unneccessary params
              params_to_pass = if arity > 0
                                 msg.params[0..min_arity-2]
                               else
                                 msg.params
                               end

              command_method.call(self, *params_to_pass)
            else
              unless @server.plugin_command msg
                raise IrcError.new(ERR_UNKNOWNCOMMAND, msg.command, ':Unknown command')
              end
            end
          rescue IrcError => e
            server_message e.error_no, *e.params unless e.error_no.nil?
          end

          process_send_queue
        end
      end

      debug_print 'Session closed'
    end

    def quit_command(user, reason='')
      quit 'Quit: ' + reason
      throw :quit_next_message_loop
    end

    def pass_command(user, password)
      @password = password
      check_registration
    end

    def user_command(user, username, hostname, servername, realname)
      @username = "~#{username}" unless @valid_ident
      # @hostname = hostname
      @servername = servername
      @realname = realname
      check_registration
    end

    def nick_command(user, new_nickname)
      @server.request_nickname_change(self, new_nickname)
      check_registration
    end

    def join_command(user, channel_list, key_list='')
      names = channel_list.split(",")
      keys = key_list.split(",")
      names.each_with_index do |name, index|
        @server.create_channel name
        @server.get_channel(name).join_request(self, keys[index.to_i])
      end
    end

    def part_command(user, channel_list, reason='')
      channel_list.split(",").each do |name|
        get_channel_ensured(name).part_request(self, reason, true)
      end
    end

    def privmsg_command(user, reciever_list, content)
      do_msg('PRIVMSG', reciever_list, content)
    end

    def notice_command(user, reciever_list, content)
      do_msg('NOTICE', reciever_list, content)
    end

    def do_msg(command, reciever_list, content)
      #TODO add a juncture to plugins for disallowing sending private messages at all
      receiver_names = reciever_list.split(",").uniq
      receiver_names.each do |name|
        if name[0..0] == '#'
          receiver = @server.get_channel name
        else
          receiver = @server.get_user name
        end
        if receiver.nil?
          if command == 'NOTICE'
            raise IrcError.new(nil)
          else
            raise IrcError.new(ERR_NOSUCHNICK, name, ':No such nick/channel')
          end
        end
        receiver.message_request self, command, content
      end
    end

    def ping_command(user, content)
      send_message ":#{@server.hostname}", 'PONG', @server.hostname, ":#{content}"
    end

    def topic_command(user, channel_name)
      #TODO add implementation to change the topic (needs at least modes)
      channel = get_channel_ensured channel_name
      server_message RPL_NOTOPIC, channel_name, ':No topic is set' if channel.topic.empty?
      server_message RPL_TOPIC, channel_name, ":#{channel.topic}" unless channel.topic.empty?
    end

    def mode_command(user, name, *params)
      if params.empty?
        #TODO request of the modes of a user (global) or of a channel
      else
        if name[0..0] == '#'
          @server.get_channel(name).parse_modestring_request(self, params[0], params[1..-1])
          # else
          #  user = @server.get_user msg.params[0]
          #  if !user.nil?
          #    #TODO apply global modes
          #  end
        end
      end
    end

    def check_registration
      if !@registered && !@username.nil? && !@nickname.nil?
        @server.plugins_for(:pre_registration).call_each.pre_registration(self)

        @registered = true
        server_message '001', ":Welcome on this RubyIRCd server, #{@nickname}"

        server_message RPL_MOTDSTART, ":- #{@server.hostname} Message of the day - "
        server_message RPL_MOTD, ':- MOTD not implemented yet'
        server_message RPL_ENDOFMOTD, ':End of /MOTD command'
      end
    end

    def connected_users
      users = []
      @channels.each_value do |channel|
        users.concat channel.users
      end
      users.uniq
    end

    def quit(reason='')
      @quitting = true
      @socket.close

      reason = "Signed off" if reason.nil? || reason.empty?

      @channels.each_value do |channel|
        channel.part_request(self)
        #TODO Add check for chanmode +u (stripping quit messages)
      end
      connected_users.each do |to|
        to.send_message ":#{@nickname}!#{@username}@#{@hostname}", 'QUIT', ":#{reason}"
      end
    end

    def channel_joined(channel)
      @channels[channel.name] = channel
    end

    def channel_parted(channel)
      @channels.delete channel.name
    end

    def message_request(sender, type, msg)
      #TODO add a juncture to plugins for disallowing sending messages to the receiver
      send_message ":#{sender.nickname}!#{sender.username}@#{sender.hostname}", type, @nickname, ":#{msg}"
    end

    def server_message(command, *params)
      send_message ":#{@server.hostname}", command, @nickname || '*', *params
    end

    def send_message(*parts)
      debug_print '<< ' + parts.join(' ')
      if Thread.current == @listen_thread
        @send_queue << parts.join(' ') # add to send queue
      else
        socket_send parts.join(' ') + "\r\n" # send immediately
      end
    end

    private # -------------------------------------------

    def get_next_message
      while @message_buffer.empty?
        data = @socket.recvfrom(1024)[0]
        return false if data.empty?
        data.split("\n").each do |line|
          line.chomp!
          next if line.empty?
          debug_print ">> #{line}"
          msg = Message.new(line)
          @message_buffer.push msg unless msg.nil?
        end
      end
      @message_buffer.pop
    rescue Errno::ECONNRESET
      return false
    end

    def process_send_queue
      return if @send_queue.empty?
      socket_send @send_queue.join("\r\n") + "\r\n"
      @send_queue.clear
    end

    def socket_send(data)
      @socket.send data, Socket::MSG_DONTWAIT
    end

    def get_channel_ensured(name)
      channel = @server.get_channel name
      raise IrcError.new(ERR_NOSUCHCHANNEL, name, ':No such channel') if channel.nil?
      channel
    end

    def debug_print(msg)
      @server.log :debug, "#{@id}: #{msg}"
    end
  end
end
