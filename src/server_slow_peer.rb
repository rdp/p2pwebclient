#!/usr/bin/ruby
require_relative 'constants' # fileSize
require_relative './driver.rb'

if $0 == __FILE__ or debugMe('server_slow_peer')
  if ARGV[0] == '--help' or ARGV[0] == '-h'
   print "usage filesize (Bytes), port, limit B/s [or blank] \n"
   exit
  end
  port = ARGV[1] || Driver.servers_port
  port = eval(port.to_s)
  print "using peer (as a fake http server) port of #{port}...forever..."
  Driver.initializeVarsAndListeners
  fileSize = Driver.class_eval "@@fileSize"
  fileUrl = Driver.recalculateCurrentGlobalUrl fileSize
  serverBpS = $serverBpS

  if ARGV.length > 0
   fileSize = eval(ARGV[0])
   print 'using file size', fileSize
  end

  Dir.mkPath "../logs/server" # tltodo have mkPath check if already there :)
  EventMachine::run {
      limit = eval(ARGV[2]) if ARGV[2] # if it exists :)
      BlockManager.startPrefabServer(fileUrl, port, fileSize, limit)# last is speed limit B/s
  }
  
end
