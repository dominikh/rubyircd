version '0.0.1'

register_mode :channel, 'N'

def pre_nickname_change(user, new_nick)
 blocking_channels = user.channels.select { |channel| channel.mode_set? 'N' }
 return true if blocking_channels.empty?
 user.server_message 447, ":Can't change nickname while on #{blocking_channels.names.join(', ')} (+N is set)"
 return false
end
