  require 'rev_here'
  HOST = 'localhost'
  PORT = 4322

  class EchoServerConnection < Rev::TCPSocket
    def on_connect
      puts "#{remote_addr}:#{remote_port} connected #{@@list}"
    end

    def on_close
      puts "#{remote_addr}:#{remote_port} disconnected"
    end

    def on_read(data)
      write data
    end
  end

  server = Rev::TCPServer.new('localhost', PORT, EchoServerConnection)
  server.attach(Rev::Loop.default)

  puts "Echo server listening on #{HOST}:#{PORT}"
  #Rev::Loop.default.run
