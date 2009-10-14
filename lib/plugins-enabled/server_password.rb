version '0.0.1'

def pre_registration(user)
  raise IrcError.new(ERR_PASSWDMISMATCH, ':Password incorrect') unless configuration.server_password.to_s.empty? or user.password == configuration.server_password
end