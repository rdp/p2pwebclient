require 'test/unit'
require 'constants'
require 'eventmachine'
require 'lib/ruby_useful_here'
class TestUseful < Test::Unit::TestCase

  def setup
    def assure_em_started
      if !EM::reactor_running?
        @running_em_thread = Thread.new { EM::run {} }
      end
    end
    assure_em_started
  end
  
  def teardown
    EM::stop if EM::reactor_running?
    @running_em_thread.join if @running_em_thread
  end

  def test_multiple
    require 'open-uri'
    begin
      url = open('http://opendht.org/servers.txt')
      timeLine = url.readline
      allServers = url.read
      url.close
    rescue => detail
      print "ack erred downloading ser"
    end
    allServers = allServers.split("\n")
    allServerArrays = []
    for server in allServers
      allServerArrays << [server.split("\t")[1].split(':')[0], 5851]
    end
    goodPeers2 = calculateXQuickestPorts allServerArrays, 5, 30#, 5, 6 # 5s timeout, or after 6 found
    pp "of 30 random, 5 fastest, stop after get 6, were", goodPeers2
    goodPeers = calculateXQuickestPorts  allServerArrays, 2, 100#, 5, 6 # 5s timeout, or after 6 found
    pp "got 2 good peers (stop after first 6) 100 random of", goodPeers
    goodPeers = calculateXQuickestPorts  allServerArrays, 50, 200 #, 5, 6 # 5s timeout, or after 6 found
    pp "got 50 best out of 200", goodPeers
    # fail  goodPeers = calculateXQuickestPorts  allServerArrays #, 5, 6 # 5s timeout, or after 6 found
    # fail  pp "got 50 best out of 200", goodPeers
  end

  def test_open
    assert(EventMachine.portOpen?('www.google.com', 80))
    assert(!EventMachine.portOpen?('localhost', 79))
  end

  def test_count
    count_expected = 1000
    if RUBY_PLATFORM =~ /darwin/
      count_expected = 200 # so low! ugh
    elsif RUBY_PLATFORM =~ /w.*32/
      count_expected = 500
    end
    count = fileDescriptorsAvailable
    assert count > count_expected
    count = fileDescriptorsAvailable
    assert count > count_expected
  end
  
end