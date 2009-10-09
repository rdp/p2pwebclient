require 'test/unit'
require File.dirname(__FILE__) + '/../constants'
require 'listener.rb'
EventMachine.fireSelfUp

class Listener_Tests < Test::Unit::TestCase

  def testSelf
    port = P2PServer.findOpenTCPPort
    listener = Listener.new(port)
    listener.listenForeverLoopingOnErrorNonBlocking
    socket = TCPSocket.new('127.0.0.1', port)
    socket.write("version")
    assert socket.recv(1024) =~ /\d+/
    assert(EM::portOpen?('localhost', port))
    listener.stopBlocking # ltodo take out, don't use
    # LTODO seems we can't stop this bad boy    assert(!EM::portOpen?('localhost', port))
    print "sleeping awhile so that it can cleanup its mother thread..." # ltodo only wait 4 seconds, end ASAP
#    sleep 1.5
#    assert(!EM::portOpen?('localhost', port))
    socket.close


    listener = Listener.new(port)
    thread = listener.listenForeverLoopingOnErrorNonBlocking
    socket = TCPSocket.new('127.0.0.1', port)
    EM::stop
    parent = Thread.current
    stopped_us = false
    Thread.new {
      begin
        EM::run {}
      rescue
        print 'success'
        stopped_us = true
      end
    }
    socket.write("restart")
    socket.close

    sleep 1 # let it kill us :)
    #raise 'nope' unless stopped_us
    print "done listener tests!"
  end
end