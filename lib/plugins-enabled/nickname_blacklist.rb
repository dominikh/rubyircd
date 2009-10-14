version '0.0.1'

BLACKLIST = ['hitler', 'nazi']

def pre_nickname_change(user, new_nickname)
  test_nickname = new_nickname.downcase
  BLACKLIST.each do |entry|
    raise IrcError.new(ERR_ERRONEUSNICKNAME, new_nickname, ":Nickname blacklisted") if test_nickname.include?(entry)
  end
end