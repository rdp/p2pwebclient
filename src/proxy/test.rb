require 'rev_echo'
  server = Rev::TCPServer.new('localhost', PORT, EchoServerConnection)
  server.attach(Rev::Loop.default)

  puts "Echo server listening on #{HOST}:#{PORT}"
  Rev::Loop.default.run

