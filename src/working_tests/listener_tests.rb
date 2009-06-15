require 'test/unit'
require 'constants'
require 'listener.rb'
EventMachine.fireSelfUp

class Listener_Tests < Test::Unit::TestCase

  def testSelf
    port = P2PServer.findOpenTCPPort
    listener = Listener.new(port)
    listener.listenForeverLoopingOnErrorNonBlocking
    socket = TCPSocket.new('127.0.0.1', port)
    socket.write("version")
    assert socket.recv(10000) =~ /\d+\.\d+/
    listener.stopBlocking # ltodo take out, don't use
    print "sleeping awhile so that it can cleanup its mother thread..." # ltodo only wait 4 seconds, end ASAP
    sleep 1.5
    assert(!EM::portOpen?('localhost', port))
    socket.close
    return # ltodo test this :) err rather have like a thread that returns, more like it :)
    


    listener = Listener.new(port)
    thread = listener.listenForeverLoopingOnErrorNonBlocking
    socket = TCPSocket.new('127.0.0.1', port)
    EM::stop
    parent = Thread.current
    Thread.new {
    begin
      broke = false
      EM::run {}
    rescue
      print 'success'
      broke = true
    end
    parent.raise if !broke
    }
    socket.write("hup")
    socket.close
    
    sleep 1 # let it kill us :)
    print "done listener tests!"
  end
end
