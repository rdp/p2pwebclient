require 'driver'
require 'lib/block_manager'
require 'test/unit'
require 'socket'
#Driver.throwUpServer
#Driver.throwUpListener
EventMachine.fireSelfUp # start it, at least :)
require 'lib/opendht/opendht_em_fake.rb'
Driver.class_eval('@@useLocalHostAsServer = true')

# TODO have it wait, per block, for set to come back before rm goes out -- make sure it doesn't fire its 'done' thing, though.  Maybe set up some tie-ins 'run this first, when round X ever gets back'

class ServerTester < Test::Unit::TestCase # some are in the old driver tests!!
  def setup
    Driver.initializeVarsAndListeners
    Driver.newFileName
    @server = BlockManager.startPrefabServer unless @server # once for now :)
    @logger = Logger.new('test/test_bm_units', 7000)
  end
  
  def teardown
    @logger.close
    @server.doFinalize
    @server = nil
    #Driver.tearDownServer # these both might be anathema
    #Driver.tearDownListener
  end

  def test_server_serves_slowly
    @server.p2pServer.speedLimitPerConnectionBytesPerSecond = 2
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 30, 0,"first_getter6",0,'fake_run_name_potatoe', 100, @logger)
    sleep 4
    assert getter.totalBytesWritten > 0
    assert getter.totalBytesWritten < 10
    getter.doFinalize
  end
  
  def test_server_start
    server = BlockManager.startPrefabServer($fileUrl, 8001)
    server2 = BlockManager.startPrefabServer($fileUrl, 8002)
    for port in [8001, 8002]
      a = TCPSocket.new('127.0.0.1', port)
      a.close
    end
    for server_instance in [server, server2] do server_instance.doFinalize end
  end
  
  def test_server_stop
    server = BlockManager.startPrefabServer($fileUrl, 8003)
    server2 = BlockManager.startPrefabServer($fileUrl, 8004)
    server.p2pServer.serverCanStopNowNonBlocking
    server2.p2pServer.serverCanStopNowNonBlocking
    for port in [8003, 8004]
      begin
        a = TCPSocket.new('localhost', port)
        a.close
        assert false, "should have closed" # ltodo 'should throw'
        rescue
        # okay
      end
    end
    
  end
 
  def test_seems_to_serve_in_chunks_real_serving_not_fake # ltodo automate this..hmm.
    old_file_size = $fileSize
    $fileSize = 2.mb
    @server.doFinalize
    @server = BlockManager.startPrefabServer($fileUrl)
    @server.p2pServer.speedLimitPerConnectionBytesPerSecond = nil
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3.mb, 0, 3, 0, "first_getter7", 0, 'fake run chunks', 100, @logger)
    sleep 0.1 while !getter.done?
    $fileSize = old_file_size
   
  end
 
end
  
