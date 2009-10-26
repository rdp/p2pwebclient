require File.dirname(__FILE__) + "/../constants"
require 'driver'
require 'lib/block_manager'
require 'test/unit'
require 'socket'
#Driver.throwUpServer
#Driver.throwUpListener
EventMachine.fireSelfUp # start it, at least :)
raise unless EventMachine::reactor_running?
require 'lib/opendht/opendht_em_fake.rb'
Driver.class_eval('@@useLocalHostAsServer = true') # I assume this makes a difference...maybe? maybe unused?

# TODO have it wait, per block, for set to come back before rm goes out -- make sure it doesn't fire its 'done' thing, though.  Maybe set up some tie-ins 'run this first, when round X ever gets back'
class BlockManager
  def wait_till_done message = '.'
    sleep(0.5) && (print message + @stage.to_s) && STDOUT.flush while !done?
  end
  def close_and_wait
    doFinalize
    wait_for_opendht
  end
  def wait_till_totally_done
    wait_till_done
    close_and_wait
  end
  def wait_for_opendht
    sleep 0.1 while !@opendht.done_and_clean? # this will miss a few things, still, but probably get everything.
  end
end

class BMTester < Test::Unit::TestCase # some are in the old driver tests!!
  def setup
    $fileUrl = calculateCurrentGlobalUrl 102.kb
    $useLocalHostAsServer = true
    @dht_class =  BlockManager.class_eval('@@default_dht_class')
    print "starting server #{$fileUrl}\n"
    
    begin
      server = BlockManager.startPrefabServer # once for now :)
      @server = server
    rescue RuntimeError
      print 'server barfed on startup please fix!!!'
    end
    Driver.initializeVarsAndListeners
    Driver.newFileName
    @logger = Logger.new('test/test_bm_units', 7000)
    @dht_subject = @dht_class.new(@logger)
    
    @opts =  {:fullUrl => $fileUrl, :dTToWaitAtBeginning => 1, :dRIfBelowThisCutItBps => 20.kbps, :dWindowSeconds => 3, :blockSize => 60000, :spaceBetweenNew => 0, :startTime => 0, :totalSecondsToContinueGeneratingNewClients => 0, :runName => 'fake_run_name_potatoe', :serverBpS => 100, :generic_logger => @logger, :linger => 180, :peer_tokens => @@testing_peer_tokens, :peer_name => 'testing_peer'}
  end
  
  def teardown
    @logger.close if @logger
    @server.doFinalize if @server
    sleep 0.1 while !@dht_subject.done_and_clean? if @dht_subject
    #Driver.tearDownServer # these both might be anathema
    #Driver.tearDownListener
  end
  
  def test_filesize_gets_set_by_straight_cs
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 10, 0,0,0,'fake_run_name_sets_file_size_cs', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_totally_done
    assert get_results(BlockManager.url_as_header_key($fileUrl)).length > 0
  end
  
  def test_filesize_gets_set_by_straight_p2p
    dt = 0.02
    getter = BlockManager.startCSWithP2PEM($fileUrl, dt, 200000, 3, 3200, 0, 2, 0,rand(1000),0,'fake_run_nameset_filesize', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_totally_done
    assert get_results(BlockManager.url_as_header_key($fileUrl)).length > 0
  end # ltodo add in tests 'it gets it via HEAD, via oDHT'
  
  def test_downloads_from_server
    getter = nil
    linger = 0
    EM::next_tick {getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,rand(1000),0,'fake_run_nameadd', 100,@@testing_peer_tokens, @logger) }
    sleep 0 until getter
    getter.wait_till_done
    getter.close_and_wait
  end
  
  def test_add_to_dht
    linger = 1800 # needs to be long. Sigh.
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,rand(1000),0,'fake_run_nameadd', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_done
    getter.wait_for_opendht
    assertEqual get_results($fileUrl + '_peers_for_block_num_1').length , 1
    getter.close_and_wait
  end
  
  def test_remove_from_dht
    linger = 2
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,rand(1000),0,'fake_run_nameremove', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_done
    sleep linger
    getter.close_and_wait
    assertEqual get_results($fileUrl + '_peers_for_block_num_1').length, 0
  end
  
  def set_last_results(status, results)
    @latest_status = status
    @latest_results = results || [] # make sure it gets loaded with something!
  end
  
  
  def get_results key
    @latest_results = nil
    @dht_subject.get_array(key, 'generic get results', proc {|status, results, pm, round, key_used| set_last_results(status, results)})
    sleep 0.1 while !@latest_results
    @latest_results
  end
  
  def test_add_and_remove_from_dht
    linger = 600
    getter = nil
    EM::next_tick {
      getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,rand(1000),0,'fake_run_nameaddandremove', 100,@@testing_peer_tokens, @logger)
    }
    sleep 0 until getter
    getter.wait_till_done 
    sleep 0.2 while !getter.opendht_no_connections?
    assert get_results($fileUrl + '_peers_for_block_num_1').length > 0
    getter.close_and_wait
    assert get_results($fileUrl + '_peers_for_block_num_1').length == 0
  end
  
  def test_doesnot_set_file_size_twice
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 2, 0,rand(1000),0,'fake_run_nameaddandremove', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_totally_done
    getter3 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 2, 0,rand(1000),0,'fake_run_nameaddandremove', 100,@@testing_peer_tokens, @logger)
    getter3.wait_till_totally_done
    assertEqual get_results(BlockManager.url_as_header_key($fileUrl)).length, 1
  end
  
  def test_doesnot_set_file_size_twice_with_more_peers
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 2, 0,rand(1000),0,'fake_run_nameaddandremove', 100,@@testing_peer_tokens, @logger)
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 2, 0,rand(1000),0,'fake_run_nameaddandremove', 100,@@testing_peer_tokens, @logger)
    sleep 0.2 while !getter.opendht_no_connections?
    sleep 0.2 while !getter2.done?
    sleep 0.2 while !getter.opendht_no_connections?
    getter3 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 2, 0,rand(1000),0,'fake_run_nameaddandremove', 100,@@testing_peer_tokens, @logger)
    getter3.wait_till_totally_done
    getter2.close_and_wait
    getter.close_and_wait
    assert get_results($fileUrl).length <= 2
  end
  
  def test_does_dt opts = {}
    # now they must get it from the peer only
    @opts.merge!(:dRIfBelowThisCutItBps => 1)
    @opts.merge!(:dWindowSeconds => 1000)
    @opts.merge!(:dTToWaitAtBeginning => 0.0001)
    @opts.merge!(opts)
    getter2 = BlockManager.startCSWithP2PEM(@opts)
    Timeout::timeout( 5 ){ getter2.wait_till_done }
    getter2.close_and_wait
  end
  
  def test_does_dr
    @server.doFinalize
    @server = BlockManager.startPrefabServer :speed_limit => 500, :size => 1000
    # ltodo: programmatically see if it says dR in there :)
    test_does_dt :dRIfBelowThisCutItBps => 10.mbps, :dWindowSeconds => 0.001, :dTToWaitAtBeginning => 1e6
  end
  
  def test_hot_potato
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 300, 0,"first_getter1",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_done
    @server.doFinalize
    # now they must get it from the peer only
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 0, 0,"second_gets_from_first_getter",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter2.wait_till_done
    getter.close_and_wait
    getter2.close_and_wait
  end
  
  def test_hot_potato_mashes
    hot_potato_mash(1, 5)
    return
    hot_potato_mash(1, 1)
    hot_potato_mash(1, 5)
    hot_potato_mash(2, 10)
    hot_potato_mash(2, 50)
    hot_potato_mash(10, 50)
    hot_potato_mash(25, 50)
    hot_potato_mash(25, 25)
    hot_potato_mash(10, 100)
    hot_potato_mash(1, 100)
  end
  
  # LTODO test which is...uh...ah with different block sizes it should still...umm...be able to at least serve the file!
  def hot_potato_mash(start_number, get_from_them_number) # make sure it doesn't fail with file stuffs
    print "doing mash #{start_number} to #{get_from_them_number} recipients\n"
    all_getters = [] 
    opts =  {:fullUrl => $fileUrl, :dTToWaitAtBeginning => 1, :dRIfBelowThisCutItBps => 200000, :dWindowSeconds => 3, :blockSize => 60000, :spaceBetweenNew => 0, :startTime => 0, :totalSecondsToContinueGeneratingNewClients => 0, :runName => 'fake_run_name_potatoe', :serverBpS => 100, :generic_logger => @logger, :linger => 180, :peer_tokens => @@testing_peer_tokens}
    
    start_number.times{|n|
      all_getters << BlockManager.startCSWithP2PEM(opts.merge(:peer_name => "seeder_#{n}"))
    } #k now have like 50 of them only get it from them
    
    all_getters[0].wait_till_done 'first not done yet'
    print "at least the first one of them finished downloading, at least\n"
    @server.doFinalize
    get_from_them_number.times {|n|
      # now they must get it from the start peers only
      all_getters  << BlockManager.startCSWithP2PEM(opts.merge(:peer_name => "harvester_#{n}"))
    }
    
    for getter in all_getters[1..-1] do
      getter.wait_till_done
      print "got done mash!\n"
      assert getter.fileIsCorrect?
    end
    
    for getter in all_getters
      getter.wait_till_totally_done
    end
  end  
  
  def test_one_peer_that_leaves_forever_and_no_origin
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 180, 0,"first_getter2",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_done
    @server.doFinalize
    # now they must get it from the peer only
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 180, 0,"second_gets_from_first_getter",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter2.wait_till_done
    
    getter.p2pServer.serverCanStopNowNonBlocking # it's still listed on DHT, but its server ain't
    getter3 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 0, 0,"third_gets_from_second_getter",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter3.wait_till_totally_done
    getter.doFinalize
  end
  
  def test_hot_potato_3
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 180, 0,"first_getter2",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_done
    @server.doFinalize
    # now they must get it from the peer only
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 180, 0,"second_gets_from_first_getter",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter2.wait_till_done
    getter.doFinalize # done with first guy, now 2 has it
    getter3 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 0, 0,"third_gets_from_second_getter",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter3.wait_till_totally_done
  end  
  
  def fake_test_download_with_faulty_opendht_fake_non_em 
    OpenDHTEMFake.setFailureLevel(90) # good luck! -- we use fake by specifying it, below, so we're ok
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 30, 0,"first_getter3",0,'fake_run_name_potatoe', 100, @logger, OpenDHTEMFake)
    getter.wait_till_done
    @server.doFinalize
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 30, 0,"second_getter",0,'fake_run_name_potatoe', 100, @logger, OpenDHTEMFake)
    getter2.doFinalize
    getter.doFinalize
    getter2.close_and_wait
    getter.close_and_wait
    OpenDHTEMFake.setFailureLevel(1)
  end
  
  @@testing_peer_tokens = 4
  
  def test_still_fast_with_slow_peer_with_many_peer_tokens
    linger = 300
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,"first_getter_becomes_slow",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_done
    getter.wait_for_opendht
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,"sec_getter_fast",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter2.wait_till_done
    getter2.wait_for_opendht
    getter.p2pServer.speedLimitPerConnectionBytesPerSecond = 10 # throw a slow one in there
    @server.doFinalize # stops serving
    getter3 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,"3_getter",0,'fake_run_name_potatoe', 100, 40, @logger) # 40 is many
    sleep 10 # should be long enough
    assert false, "should have been done by now!" unless getter3.done?
    for peer in [getter, getter2, getter3] do peer.doFinalize end
    for peer in [getter, getter2, getter3] do peer.close_and_wait end
  end
  
  def test_still_fast_with_slow_peer_few_peer_tokens
    linger = 300
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,"first_getter_becomes_slow",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter.wait_till_done
    getter.wait_for_opendht
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,"sec_getter_fast",0,'fake_run_name_potatoe', 100,@@testing_peer_tokens, @logger)
    getter2.wait_till_done
    getter2.wait_for_opendht
    getter.p2pServer.speedLimitPerConnectionBytesPerSecond = 10 # throw a slow one in there
    @server.doFinalize # stops serving
    getter3 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, linger, 0,"3_getter",0,'fake_run_name_potatoe', :serverBpS => 100, :peer_tokens => 5, :generic_logger => @logger) # 5 is few, and must be greater than Block::@max_connections_to_a_peer
    sleep 10 # should be long enough
    assert false, "should have been done by now!" unless getter3.done?
    for peer in [getter, getter2, getter3] do peer.doFinalize end
    for peer in [getter, getter2, getter3] do peer.close_and_wait end
  end
  
  def fake_test_opendht_starts_buggy
    # this one only seems to matter with the fake one, which is ok.
    getter = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 30, 0,"first_getter5",0,'fake_run_name_potatoe', 100, @logger, OpenDHTEMFake)
    sleep 0.2 while !getter.done?
    @server.doFinalize
    @dht_class.class_eval("@@count_to_fail = 20")
    getter2 = BlockManager.startCSWithP2PEM($fileUrl, 1, 200000, 3, 3200, 0, 30, 0,"getter",0,'fake_run_name_potatoe', 100, @logger, OpenDHTEMFake)
    getter2.wait_till_done
    getter.close_and_wait
    getter2.close_and_wait
  end
  
  def test_when_server_appears_late
    @server.doFinalize
    file_name = "http://localhost:8008/a" + rand(1000000).to_s
    getter = BlockManager.startCSWithP2PEM(file_name, 1, 200000, 3, 3200, 0, 0, 0,"first_getter7",0,'fake_run_name', 100,@@testing_peer_tokens, @logger)
    sleep 5 # make it spin :)
    server = BlockManager.startPrefabServer(file_name, 8008)
    getter.wait_till_done
    getter.close_and_wait
  end
end