module RubyIRCd
  class Channel
    attr_reader :name, :topic

    def initialize(server, name)
      @server = server
      @name = name
      @users = SynchronizableArray.new
      @modes = {self => {}}

      @topic = ""
    end

    def users
      @users.synchronize { @users }
    end

    def modes_for(user)
      @modes[user]
    end

    def parse_modestring_request(by, modes, params)
      if by != @server
        raise IrcError.new(ERR_NOTONCHANNEL, self.name, ":You're not on that channel") if !@users.include? by
        raise IrcError.new(ERR_CHANOPRIVSNEEDED, self.name, ":You're not channel operator") if !@modes[by]['o']
      end

      applied_modes = {:+ => [], :- => []}
      applied_params = []
      cur_method = nil
      single_param = (params.size == 1)
      modes.split('').each do |char|
        param = nil
        if char == '+' or char == '-'
          cur_method = char.to_sym
          next
        end

        next if cur_method.nil?

        type = @server.mode_type char
        case type
        when :channel, :channel_parameterized
          target = self
          if type == :channel_parameterized and cur_method == :+
            break if params.empty?
            param = params.shift
          end
        when :user
          if single_param
            param = params[0]
          else
            break if params.empty?
            param = params.shift
          end
          target = @server.get_user param
          next if target.nil?
        else
          next
        end

        if cur_method == :+
          unless @modes[target].has_key?(char)
            @modes[target][char] = param || true
            applied_modes[:+] << char
            applied_params << param unless param.nil?
          end
        elsif cur_method == :-
          if @modes[target].has_key?(char)
            @modes[target].delete(char)
            applied_modes[:-] << char
            applied_params << param unless param.nil?
          end
        end
      end
      output = ''
      output += "+#{applied_modes[:+].join}" unless applied_modes[:+].empty?
      output += "-#{applied_modes[:-].join}" unless applied_modes[:-].empty?
      output += ' ' + applied_params.join(' ') unless applied_params.empty?
      # FIXME actually it won't work to let the server set any mode because.. i don't know how to send the message then...
      message_users ":#{by.identifier}", "MODE", @name, output
      true
    end

    def join_request(user, key)
      # TODO add invite only
      # TODO add bans
      if @users.include?(user)
        return false
      end

      if @modes[self]['k'] and @modes[self]['k'] != key
        user.server_message ERR_BADCHANNELKEY, @name, ':Cannot join channel (+k)'
        return false
      end

      @users.synchronize do
        user.channel_joined self
        @users << user
        @modes[user] = {'o' => true} if @users.size == 1
        @modes[user] ||= {}
        @users.call_each.send_message ":#{user.identifier}", 'JOIN', @name

        user.server_message RPL_TOPIC, @name, ":#@topic"
        userlist = @users.map do |a_user|
          prefix = mode_prefix_for(a_user)
          prefix + a_user.nickname
        end
        user.server_message RPL_NAMEREPLY, '=', @name, ':' + userlist.join(' ')
        user.server_message RPL_ENDOFNAMES, @name, ':End of /NAMES list'
      end
      true
    end

    def mode_prefix_for(user)
      prefix = ''
      prefix = '+' if @modes[user].has_key?("v")
      prefix = '@' if @modes[user].has_key?("o")
      prefix
    end

    def message_users(*message)
      @users.synchronize do
        @users.call_each.send_message *message
      end
    end

    def part_request(user, reason=nil, notify=false)
      if !@users.include?(user)
        user.server_message ERR_NOTONCHANNEL, @name, ':You\'re not on that channel'
        return false
      end
      message_users ":#{user.identifier}", 'PART', @name, ":#{reason}" if notify

      @modes.delete(user)
      @users.delete(user)
      user.channel_parted self
      true
    end

    def change_topic_request(user, new_topic)
      # TODO check channel modes
      # TODO add max topic length
      @topic = new_topic
      message_users ":#{user.identifier}", "TOPIC", @name, ":#{new_topic}"
    end

    def message_request(sender, type, msg)
      # TODO add a juncture to plugins for disallowing sending messages to the receiver
      # TODO check if external messages are allowed and if the user is on the channel
      @users.synchronize do
        @users.each do |user|
          next if user == sender
          user.send_message ":#{sender.identifier}", type, @name, ":#{msg}"
        end
      end
    end
  end
end
