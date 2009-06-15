require 'constants.rb'
require 'server_slow_peer.rb'
require 'listener.rb'
require 'driver.rb'

# ltodo in fakepeerserver change it to say serverPort
count = ARGV.shift
count ||= 50
Driver.recreateBug count.to_i
