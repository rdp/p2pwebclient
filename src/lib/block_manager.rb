require 'constants'
require 'thread' # Mutex
Dir.mkPath "/tmp/blocks" # ltodo take off
require_rel '../cs_and_p2p_client', 'opendht/opendht_em.rb', 'opendht/opendht_em_fake.rb', '../p2p_server', '../bittorrent_peer'

# ltodo test: it starts and can't get opendht headers the first time around, at least
# ltodo what if a set is still outbound when you want to RM! (test)
# ltodo case of we get file size from ODHT--don't need to re-check it
# ltodo set file size only once per err coming back (not a big prob, though, only the first 2 might err)
# ltodo appears we do a DNS on startup for local host name--I just want to kinda grab the IP faster!
# TODOR don't check + set the oDHT filesize if that's where you retrieved it from

require File.dirname(__FILE__) + '/safe_write.rb'

class BlockManager
  @@default_dht_class = OpenDHTEM
  @@allowMultipleGrabsOfSameBlock = true # hard coded here only, at least for now (unused, actually)
  @@error_retries_internal = 15
  @@close_mutex = Mutex.new
  @@p2p_no_bytes_timeout = 5.minutes # very weak timeout, useful to make sure things terminate...ever.

  @@runningCurrently = {}
  @@runningCurrentlyStillDownloading = {}
  def BlockManager.clientsStillRunning # lingering, really, or downloading (I think) ltodo rename
    @@runningCurrently
  end

  def BlockManager.clientsStillRunningAndDownloading
    @@runningCurrentlyStillDownloading
  end

  @@prefab_peer_count_getting = 2 # don't know which value to use for this!
  # doctest: raises -- a prefab server that can't bind to its prefab port should raise
  # >> EventMachine.fireSelfUp
  # >> BlockManager.startPrefabServer
  # >> BlockManager.startPrefabServer
  # AssertionFailure: this shouldn't work!

  def BlockManager.startPrefabServer(fullUrl = 'http://fake_default_url', port = $localAndForeignServerPort, size = 100.kb, speed_limit = 100.kbps, dhtClassToUse = @@default_dht_class, blockSize = 100.kb)
    assert fullUrl, 'need to pass a url'
    serverGuy = BlockManager.new(fullUrl, -1, -1, -1, blockSize, -1, -1, 700, "prefab server #{port} #{speed_limit}", -1, "trial", speed_limit || 'none', :peer_tokens => @@prefab_peer_count_getting, :server_port_num => port, :dhtClassToUse => dhtClassToUse, :register_with_global_list => false, :should_raise_on_server_port_error => true)
    serverGuy.p2pServer.speedLimitPerConnectionBytesPerSecond = speed_limit
    serverGuy.p2pServer.serveAnyRequest = true
    serverGuy.setFileSize(size, false)
    serverGuy.readFromFileOrPropagateAndSave
    return serverGuy
  end
  
  named_args_for :'self.startPrefabServer'

  # doctest: pass_log if I pass it a logger and a callback and wait, it should callback eventually.
  # >> Thread .new { EventMachine.fireSelfUp }
  # >> success = 0
  # >> BlockManager.startCSWithP2PEM 'http://wilkboardonline.com/roger/p2p/25K.file', 2,2,3,100_000,1,20,0, 'no_name', 1, 'no_name2', 3, 3, Logger.new(0),  :completion_proc => proc {success = 1}
  # >> sleep 1
  # >> success
  # => 1

  def BlockManager.startCSWithP2PEM fullUrl, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, spaceBetweenNew, linger, startTime, peer_name, totalSecondsToContinueGeneratingNewClients, runName, serverBpS, peer_tokens, generic_logger, dhtClassToUse = @@default_dht_class, completion_proc = nil, use_this_shared_logger = nil, do_not_shutdown_logger = false, termination_proc = nil
    generic_logger.debug "starting download #{fullUrl}-- creating BM, etc. go!"
    singleFileBlockManager = BlockManager.new(fullUrl, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, spaceBetweenNew, linger, startTime, peer_name, totalSecondsToContinueGeneratingNewClients, runName, serverBpS, peer_tokens, nil, dhtClassToUse, :completion_proc => completion_proc, :use_this_shared_logger => use_this_shared_logger, :do_not_shutdown_logger => do_not_shutdown_logger, :termination_proc => termination_proc)
    generic_logger.debug "created guy -- telling him to doCS [start]"
    singleFileBlockManager.doCS
    singleFileBlockManager
  end
  
  named_args_for :'self.startCSWithP2PEM'

  def initialize(fullUrl, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, spaceBetweenNew, linger, startTime, peer_name, totalSecondsToContinueGeneratingNewClients, runName, serverBpS, peer_tokens, server_port_num, dhtClassToUse, register_with_global_list = true, should_raise_on_server_port_error = nil, completion_proc = nil, use_this_shared_logger = nil, do_not_shutdown_logger = false, termination_proc = nil)
    assert peer_tokens > 0, 'poor params here peer_tokens'
    outputDirectory = Listener.getOutputDirectoryName(blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, linger, runName, serverBpS)
    Dir.mkPath outputDirectory unless File.directory? outputDirectory
    logFileName = outputDirectory +  "peer_number_#{peer_name}_start_#{startTime.to_f}.log.txt"
    @completion_proc = completion_proc
    @termination_proc = termination_proc
    @log_prefix = "BM"
    @logger = use_this_shared_logger || Logger.new(logFileName, startTime, peer_name)
    assert(fullUrl, 'no full url!')


    @uid = (fullUrl + '_p:' << peer_name.to_s << '_r:' << Time.now.to_f.to_s).sanitize
    @register_with_global_list = register_with_global_list
    @@runningCurrentlyStillDownloading[@uid] = true if register_with_global_list
    @do_not_shutdown_logger = do_not_shutdown_logger

    @@runningCurrently[@uid] = true if register_with_global_list
    @allOutGoingConnections = {} # used by generic_client to set itself ltodo do we use this?

    # 2 means keys, 4 means 2 requests per key (4 total) will be sent out
    @allBlocks = nil
    @url = fullUrl
    @urlFileName, @urlHost, @urlPort = TCPSocketConnectionAware.splitUrl(fullUrl)
    assert @urlHost, @urlPort
    @dTToWaitAtBeginning = dTToWaitAtBeginning
    @dRIfBelowThisCutItBps = dRIfBelowThisCutItBps
    @dWindowSeconds = dWindowSeconds
    @totalNumBytesInFile = nil
    @blockDefaultSize = blockSize.to_f
    @retries_remaining_if_running_in_cs_only_mode = 30.minutes # if we get this many unbind's then we'll give
    @numBlocks = nil
    @p2pServerPort = nil
    @totalBytesWritten = 0
    @peer_name = peer_name
    @total_peer_tokens_to_use_simultaneously = peer_tokens
    @linger = linger
    @am_bittorrent = fullUrl =~ Regexp.new('http://bittorrent')
    debug "single file doing reversion as am_bittorrent: #{@am_bittorrent}, #{$useOriginRevertOptimization} with dR #{dRIfBelowThisCutItBps}, dW #{dWindowSeconds} #{[fullUrl, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, linger, logFileName, startTime, peer_name].join(", ")} $getAllAtBeginning #{$getAllAtBeginning} with number on the origin of #{$useOriginBackOffOrNumberConcurrent}"
    debug Time.now.inspect
    debug RUBY_VERSION
    unless on_windows? # diagnostics on system status
      begin
        debug `uptime`.chomp + `date`.chomp + `df -h`.chomp.gsub("\n", " : ")
      rescue => e # ltodo rescue EMFILE or whatever it's called
        error "ack unable to do uptime/date, etci #{e} #{e.class}"
      end
    end

    return if @am_bittorrent # no use doing more here

    @opendht = dhtClassToUse.new(@logger, :key_multiply_redundancy => 2, :max_num_simultaneous_gateway_requests_per_query => 2, :gateway_pool_creation_race_size => 10, :gateway_pool_size => 5) # ltodo experiment with the different values for this (?) Nice 2-d graph ha ha
    # NB: if you set it to more requests than key redundancy, it currently repeats rounds immediately after the first successful returns...which might cause some redundancy and overload...
    @p2pServer = P2PServer.new(self, @logger, server_port_num)
    @p2pServer.startServer
    assert self.p2pServerPort, "hmm no p2p server port specified! yet expected"
    raise 'unable to get the right p2p server port!' if should_raise_on_server_port_error and self.p2pServerPort != server_port_num
    @log_prefix = "BM (#{self.p2pServerPort})"

    ping_time_every = 10
    @pingTimer = EventMachine::PeriodicTimer.new(ping_time_every, proc {
      if File.exist? 'stop_now'
        debug "requiring ruby-debug"
        require 'ruby-debug'
        debugger
      end
    debug "ping #{ping_time_every} server (outgoing) conns: #{@p2pServer.aliveServerObjects.length} :#{@p2pServer.port}"}
    )
    debug "post initialize for a BM"
    @peers_in_use_for_various_blocks_counter = {}
  end
  
  attr_reader :peers_in_use_for_various_blocks_counter, :logger
  named_args_for :initialize

  attr_reader :opendht, :url, :p2pServer, :urlFileName, :totalBytesWritten, :blockDefaultSize, :opendht_done_and_logger_closed, :allOutGoingConnections, :logger, :stage,  :already_finalized
  attr_accessor :p2pServerPort

  def postCS status
    debug "post CS got status #{status}!"
    @stage = :post_cs

    if done?
      debug "guess CS just downloaded the whole thing"
      postFileSize
    else

      if $PRETEND_CLIENT_SERVER_ONLY
        # ltodo move this away -- very far away -- from a global
        @retries_remaining_if_running_in_cs_only_mode -= 1
        error "meep meep uh oh -- we were about to head into p2p on a CS only run -- is the server turned on? restarting with #{@retries_remaining_if_running_in_cs_only_mode} retries remaining then we'll just give up"
        if @retries_remaining_if_running_in_cs_only_mode == 0
          error "giving up"
          doFinalize # meep meep
        else
          assert @retries_remaining_if_running_in_cs_only_mode > 0
          debug "repeating CS in 1"
          EM::Timer.new(1) { doCS }
        end
        return # done
      end
      if !fileSizeSet?
        debug "CS didnt set the file for me! not nice!"
        setFileSizeSomehow
        # ltodo re-use the intro socket...how?    Not interrupt it, perhaps :)
      else
        debug "I think CS set the file size for me! Nice!"
        if done?
          debug "not etting the headers in the DHT, as we downloaded the whole thing via CS only, so may as well not hammer it too much...cept that we also still register ourselves...ltodo figure out"
        end
        postFileSize
      end
    end
  end

  def check_if_file_size_already_set_in_dht_else_set_it status, values
    if status == :success
      has_right_value_already = false
      for value in values
        if value.to_i != wholeFileSize
          error "DHT has bad value! #{value} (theirs) != #{wholeFileSize}"
        else
          has_right_value_already = true
        end
      end
      if has_right_value_already
        debug "not re-setting file size in DHT--already set to right value at least once"
      else
        debug "setting filesize in dht -- its not in there"
        if @already_told_dht_to_set_file_size
          debug "not setting it redundantly a second time--at least one of the keys didn't have it, and we have already instructed it to reset all of them" # ltodo just set it one key at a time, and if necessary
          return
        else
          @already_told_dht_to_set_file_size = true
          debug "setting file size in dht"
          @opendht.add(BlockManager.url_as_header_key(@url), wholeFileSize, 'set file size round', 'set file size description')
        end
      end
    else
      error "got dht check of failure from one gateway/key/x--odd, unaccounted for"
    end
  end
  #

  def repeat_add_until_done key, value, round_id = nil, description = '', this_many_repeats_left = 3, &block
    round_id ||= key + value.to_s + rand(1000000).to_s
    raise "unexpected non block!" unless block_given?

    @opendht.add(key, value, :round_id => round_id, :description => description, :retry_times => 0, :block_proc => proc{|status, values, round, key|
      if status == :success or this_many_repeats_left == 0 or @already_finalized
        block.call(status, values, round, key) if block
      else
        debug "repeating because #{status} and #{this_many_repeats_left}x left and we're not finalized yet"
        repeat_add_until_done key, value, round_id, description, this_many_repeats_left - 1, &block
      end
    }

    )
  end
  named_args_for :repeat_add_until_done

  def set_file_size_opendht
    assert fileSizeSet?
    assert !@already_set_filesize_in_opendht
    @already_set_filesize_in_opendht = true
    debug "doing set file size opendht called--checking first, then setting"
    @opendht.get_array(BlockManager.url_as_header_key(@url), 'set file size check once first round', proc {|status, values, pm, round, key| check_if_file_size_already_set_in_dht_else_set_it(status, values)}, 'filesize check')
  end

  def postFileSize
    if @already_into_post_file_size
      debug "called postFileSize twice! returning second time -- possible if the set file size in the DHT threads is late, and for duplicate opemDHT returns of the same value, and we use two methods to find the file size the second one will always call this"
      return
    end
    @stage = :post_file_size
    @already_into_post_file_size = true

    assert fileSizeSet?
    if not done? # cs failed us
      unless @am_interrupted_state
        doP2P
      else
        debug 'am interrupted, so not continuing with P2P right now' # ltodo have it report 'ja' if it succeeds CS only...might already
        # if you are interrupted this means that we previously interrupted the origin, you got here--do don't add any peers you were interrupted
      end
    else
      doLinger
    end
  end

  def doLinger # this has re-entry for if a peer fails in downloading p2p ever--NB
    return if @already_did_linger # right now as it adds back in tokens it starts linger 'right then', so this avoids us when we call it more than once ltodo stinky
    @already_did_linger = true
    @stage = :do_linger
    debug "starting linger #{@linger}"
    assert @@runningCurrentlyStillDownloading.delete(@uid) if @register_with_global_list
    start_time = Time.now
    @linger_pinger = EM::PeriodicTimer.new(5, proc { debug "lingering with approx. #{@linger - (Time.now-start_time)}s left #{@url}"})
    EM::Timer.new(@linger, proc { debug 'linger up --doing finalize'; doFinalize } )
  end

  def doFinalize
    debug "doing a finalize call"
    @@close_mutex.synchronize do
      if @already_finalized
        error "finalized twice--unexpected behavior except in testing, which may call doFinalize as meaning 'shut down'"
        return
      end
      @already_finalized = true
    end
    debug "really doing finalize"
    @pingTimer.cancel
    if !@linger_pinger
      debug "uh oh linger has yet to go! ltodo make new method to be able to finalize early or something -- you probably called this as part of a test or something" # stinky
    else
      @linger_pinger.cancel
    end
    @p2pServer.serverCanStopNowNonBlocking
    for connection, true_value in @allOutGoingConnections do
      debug 'shutting down a connection?'
      connection.shutdown_once_without_writing
    end

    if @allBlocks
      for block in @allBlocks do
        block.remove_from_dht # do this before verification to speed it up
      end
      if $verifyData
        if !fileIsCorrect?
          error "FILE NOT CORRECT!! SEEDO! correctness is bad" # ltodo do not check this for large files!
        else
          debug "file correct!"
        end
      end
      for block in @allBlocks do block.delete_internal_file end # done with all those files
    else
      error "ack this better be an early run -- no blocks were ever even downloaded meaning we never even knew the file size, I'd guess!!!"
    end
    close_opendht
  end

  def hard_interrupt_download
    if @already_finalized
      error 'whoa hard interrupt an already finalized?'
    end
    assert !done?
    @cs_starter_peer.shutdown_once_without_writing if @cs_starter_peer
    for block in @allBlocks
      block.delete_all_tokens_and_shutdown_peers
    end if @allBlocks
    @am_interrupted_state = true unless done?
  end

  def restart_if_had_been_interrupted
    if @am_interrupted_state
      debug "1restarting from interrupted state #{@am_interrupted_state}"
      @am_interrupted_state = false
      debug "2restarting from interrupted state #{@am_interrupted_state}"
      if fileSizeSet?
        doP2P
      else
        postCS :interrupted_return # let it get the file head size, too :)
      end
      debug 'restarting download (p2p in case there were parts of the file downloaded already)'
      debug "3restarting from interrupted state #{@am_interrupted_state}"
    else
      debug 'not restarting for not having been interrupted'
    end
  end

  def close_opendht
    if @already_got_to_close_opendht
      error "close opendht twice--returning early and letting the previous one continue on!!!"
      return
    else
      @already_got_to_close_opendht = true
    end

    if @opendht.done_and_clean?
      error "dht says it is already done -- I would anticipate this being impossible as all the rm's should be out"
      post_cleanup
    else
      @informant = EM::PeriodicTimer.new(5, proc { debug "still waiting on opendht -- size #{@opendht.outstanding_conns_still_open.length} -- done finding live gateways is #{@opendht.done_finding_live_gateways}" } )
      @opendht.func_to_call_when_empty_which_means_we_are_in_shutdown_mode = proc { @informant.cancel; post_cleanup } # it will call that for us, later--this function again, that is
    end
  end

  def post_cleanup
    @@runningCurrentlyStillDownloading.delete(@uid) if @@runningCurrentlyStillDownloading[@uid] # remove it for the case of downloaders that fail

    unless @do_not_shutdown_logger
      log "congratulations--post cleanup called--you're done deleting uid #{@uid} "
      @logger.close
      dbg if @termination_proc
      assert !@termination_proc, 'unexpected'
    else
      @do_not_shutdown_logger
    end
    @opendht_done_and_logger_closed = true
    @termination_proc.call if @termination_proc

    assert @@runningCurrently.delete(@uid) if @register_with_global_list # global listener list -- do after so there's no chance of them asking "are we done" mid-stream
  end

  def opendht_no_connections?
    return true if @opendht_done_and_logger_closed # avoid logging
    @opendht.done_and_clean?
  end

  def totalBytesWritten
    sum = 0;
    for block in @allBlocks do; sum += block.currentSize; end
    sum
  end

  def addP2PTokens(count)
    number_distributed = 0
    count.times do
      if @allBlocksNotDone.empty?
        assert done?
        assert number_distributed == 0, "it should either be totally done or give out all tokens"
        debug "abandoning #{count} tokens"
        log "DONE WITH WHOLE FILE P2P! (or CS in border cases)"
        report_done
        doLinger
        return # return so we don't call doLinger again
      end
      guy = @allBlocksNotDone.shift
      assert guy, "should be here since we handle empty above"
      unless guy.done?
        number_distributed += 1
        guy.addToken
        @allBlocksNotDone << guy # put him on the end :)
      else
        debug "done with block #{guy} -- no tokens for you!" # don't add token
        redo
      end
    end
  end

  def report_done
    return if @already_reported_done
    @already_reported_done = true
    @completion_proc.andand.call
  end


  # doctest: should give up on p2p after a little bit
  #  Thread.new { EM.start {} }
  #
  def doP2P
    sum_written = totalBytesWritten
    a = EM::Timer.new(@@p2p_no_bytes_timeout) {
      unless @already_finalized
        if totalBytesWritten == sum_written
          error "whoa! after 10 minutes P2P hadn't downloaded a byte? giving up! going to linger!"
          hard_interrupt_download
          doLinger
        else
          sum_written = totalBytesWritten # TOTEST
          debug "p2p has written -- #{totalBytesWritten} currently > old #{sum_written} -- rescheduling p2p death timer"
          a.restart
        end
      end
    }

    @stage = :do_p2p
    addP2PTokens(@total_peer_tokens_to_use_simultaneously)
    #ltodo: future log 'doing MASS global get of blocks'
    #@allBlocks.each{|block| block.attempt_to_get_low_key} # cache some values ltodo automated testing that this happens, and appropriately
  end

  def reinsert_peer(ip, port, block_number)
    @allBlocks[block_number].reinsert_peer(ip, port)
  end

  def post_BT
    debug "post bt"
    assert @@runningCurrentlyStillDownloading.delete(@uid) if @register_with_global_list
    post_cleanup
  end

  def doCS count_remaining = @@error_retries_internal # ltodo rename--really means "do all" or "go"
    if @am_bittorrent
      #EM::next_tick { EM::next_tick {BitTorrent.do_one self }}
      BitTorrent.do_one self
      return
    end

    @stage = :do_cs
    @start_time ||= Time.now
    log "Start CS normal innocent get %s dT %f dR %f dW %f blockSize %d p2pskipCS: #{$p2pSkipCS}  PRETEND_CLIENT_SERVER_ONLY #{$PRETEND_CLIENT_SERVER_ONLY}" % [@url, @dTToWaitAtBeginning, @dRIfBelowThisCutItBps, @dWindowSeconds, @blockDefaultSize]

    if $p2pSkipCS
      error "NO NORMAL C/S breaking immediately no dT, no dR!"
      return
    else
      debug "using CS intro...(normal)"
    end

    pageStringOnly, hostToGetFrom, ipPortToGetFrom = TCPSocketConnectionAware.splitUrl(@url)
    begin
      EM.connect( hostToGetFrom, ipPortToGetFrom.to_i, GenericGetFromSinglePeer ) { |conn| # ltodo surround all connect's, accept's (double check)
        @cs_starter_peer = conn
        conn.init @url, self, @dTToWaitAtBeginning, @dRIfBelowThisCutItBps, @dWindowSeconds, @logger, "cs straight", hostToGetFrom, ipPortToGetFrom.to_i, nil, @peer_name, proc {|status| self.postCS(status)}
      }
    rescue RuntimeError => e
      error " unable to start CS--presumed lack of descriptors! arr! #{e} #{e.class}"
      if count_remaining > 0 and (Time.now - @start_time) < @dTToWaitAtBeginning # ltodo handle dR here, too
        wait_time = 2
        debug "since we haven't passed dT and just had a failure to the origin, restarting in #{wait_time}s with remaining tries #{count_remaining}"
        EM::Timer.new(wait_time, proc{ doCS count_remaining - 1})
      else
        error "Giving up on CS for file because of runtime errors! ARR"
        postCS :gave_up_on_origin
      end
    end
    return nil
  end # func

  include Logs
  @@local_ip_address = Socket.get_host_ip  # do it once, only, per instance (not per peer), so we're ok
  def localIP
    @@local_ip_address
  end

  class HeadRetriever < EventMachine::Connection
    def init fullUrl, parent, logger, done_proc
      self.set_comm_inactivity_timeout 90 # try and avoid a weirdness where at least once, a head request went out and [EM didn't handle it?] never came back
      @done_proc = done_proc
      @parent = parent
      pageStringOnly, hostToGetFrom, ipPortToGetFrom = TCPSocketConnectionAware.splitUrl(fullUrl)
      requestString = TCPSocketConnectionAware.createHTTPHeadRequest(pageStringOnly, hostToGetFrom, ipPortToGetFrom)
      send_data requestString
      @startTime = Time.new
      @logger = logger
      @logger.debug "starting HEAD request"
      @done = false
    end

    def connection_completed
      @logger.debug "HEAD conn completed -- AND we already queued the HEAD request, itself, so we're ready to receive it, now"
    end

    def receive_data received
      amPastHeader, returnable, currentTransmissionSize, totalFileSize = TCPSocketConnectionAware.parseReceiveHeader received
      totalFileSize ||= currentTransmissionSize # for those that pass it to us as Content-Length
      @logger.debug "tcp HEAD set length to #{totalFileSize} after #{Time.new - @startTime}s"
      if totalFileSize
        @parent.setFileSize(totalFileSize)
      else
        @logger.error "huh no head in #{received}"
      end
      close_connection
      done
    end

    def done
      return if @done
      @done = true
      if @parent.fileSizeSet?
        @logger.debug "HEAD request success"
        @done_proc.call(:success)
      else
        @logger.debug "HEAD request unbound early!!!"
        @done_proc.call(:failure)
      end
    end

    def unbind
      done
    end
  end

  def startHeadRetriever this_many_attempts_left
    @head_attempts_left = this_many_attempts_left
    if this_many_attempts_left == 0
      error "head retriever giving up!"
      failedGetMethod 'head retriever'
      return
    end
    assert @urlHost and @urlPort
    begin
      EM::connect(@urlHost, @urlPort, HeadRetriever ){ |conn|
        conn.init @url, self, @logger, proc {|status| headRetrieverDone(status)}
        debug "created head retriever to #{@urlHost} #{@urlPort}"
      }
      debug 'post block create head retriever'
    rescue RuntimeError
      error 'start head retriever FAILED to connect, even!'
      EM::Timer.new(5) { startHeadRetriever(this_many_attempts_left - 1) }
    end
  end

  def headRetrieverDone status
    if status == :success
      debug "head was successful!"
      postFileSize
    else
      if fileSizeSet?
        debug "head unsuccessfull -- ignoring that because apparently it was too late anyway!"
      else
        try_again_time = 5
        debug "head unsuccessful! restarting as file size not set yet! trying again in #{try_again_time} second(s), with attempts left #{@head_attempts_left}"
        EM::Timer.new(try_again_time, proc { startHeadRetriever @head_attempts_left -1 } )
      end
    end
  end
  def setFileSizeSomehow
    @total_getting_file_size = 2
    startHeadRetriever @@error_retries_internal
    getFileSizeOpenDHTIntEM @@error_retries_internal
  end

  def failedGetMethod method_name
    @total_getting_file_size -= 1
    error "ack failed get method #{method_name} -- remaining #{@total_getting_file_size}"
    if @total_getting_file_size == 0
      error 'completely giving up'
      doFinalize
    end
  end

  def fileSizeReturnedOpenDHT(status, sizes, round, times_left)
    assert round
    debug "got an opendht filesizereturned #{status}:#{sizes && sizes.length}"
    if fileSizeSet?
      debug "aww--dht gets headers useless--it was already set previously -- might have been a weird post-CS CS still sets it, though--calling forward proc anyway" # ltodo kill this when it comes in :)
    else
      if status == :success and sizes.length > 0
        for size in sizes
          if size =~ /^\d+$/ # all decimal
            size = size.to_i
            debug "got good file size set in DHT #{size}"
            assert size != 0
            setFileSize(size) # ltodo in this one case we don't need to try and set it in the DHT.
          else
            error "got bad size listed in DHT [#{size}]"
          end
        end
      else
        debug "opendht get headers failure or not set!"
      end
    end
    if !fileSizeSet?
      debug "non success or non listed file size in that dht get"
      if round == @current_odht_headers_round
        @current_odht_headers_round = nil
        reschedule_in = 5
        debug "rescheduling in #{reschedule_in}, as we got back the first of a round (times left: #{times_left})" # ltodo allow for true errs on first one back
        EM::Timer.new(reschedule_in, proc {getFileSizeOpenDHTIntEM(times_left - 1) })
      else
        debug "not rescheduling extra return"
      end
    else
      postFileSize # just in case, make sure it gets called -- we need this in the case of CS setting it after we fire off our setters
      # ltodo what if the original connection sets it half-way through--we shoudl use that!  ltodo just get the first block and set the file and spring the p2p then
    end
  end

  def BlockManager.url_as_header_key(url)
    return url + '_headers_key'
  end

  def getFileSizeOpenDHTIntEM times_left
    if times_left == 0
      error "giving up on get file size opendht!"
      failedGetMethod 'dht'
      return
    end
    @current_odht_headers_round ||= 'get file size round' # ltodo do rm's only after sets return (?)
    @current_odht_headers_round += '+'
    @opendht.get_array(BlockManager.url_as_header_key(@url), @current_odht_headers_round, proc {|status, values, pm, round, key_used|
      assert [:failure, :success].include?(status)
    fileSizeReturnedOpenDHT(status, values, round, times_left)}, ' file size') # assume works. Sigh.
  end

  def setFileSize(sizeIn, should_set_in_opendht = true)
    assert sizeIn
    assert sizeIn >= 0
    if fileSizeSet?
      error "setting file size twice?!"
      assert sizeIn == @totalNumBytesInFile
      return
    end
    @totalNumBytesInFile = sizeIn
    debug "setting file size to #{sizeIn}"
    @numBlocks = (sizeIn/@blockDefaultSize).ceil
    assert @numBlocks*@blockDefaultSize >= sizeIn, "not enough blocks--math prob"
    assert @allBlocks == nil
    assert @url and !@url.blank?
    @allBlocks = []
    @numBlocks.times do |blockNum|
      @allBlocks << Block.new(@blockDefaultSize, blockNum, @url, @uid, @logger, @urlHost, @urlPort, self)
    end

    if sizeIn % @blockDefaultSize != 0
      # then the last ending block has less than a full size
      lastBlockSize = sizeIn % @blockDefaultSize
      @allBlocks[@allBlocks.length - 1].setNewSize(lastBlockSize)
    end
    @allBlocksNotDone = @allBlocks.randomizedVersion
    set_file_size_opendht if should_set_in_opendht
  end

  def total_peer_token_count_globally
    return 0 unless @allBlocks
    sum = 0
    for block in @allBlocks
      sum += block.peerCountTokens
    end
    sum
  end

  # ltodo test of getting the one byte AFTER the file muhaha

  def addDataToBlock(blockNumber, data, offset, shouldReportToDHT)
    assert @numBlocks > blockNumber
    blockToUse = @allBlocks[blockNumber]
    assert blockToUse
    return 0 if blockToUse.done?
    amountWritten = blockToUse.addToMe(data, offset)
    # not necessarily true if we write 'over' half of something assert amountWritten == data.length
    @totalBytesWritten += amountWritten
    if blockToUse.done? and shouldReportToDHT
      assert !blockToUse.alreadyReportedDoneToDHT
      blockToUse.alreadyReportedDoneToDHT = true
      @logger.log "BM next reporting block #{blockNumber} done for #{localIP}:#{@p2pServerPort}"
      blockToUse.set_block_done_in_dht
    end
    amountWritten
  end

  def fileSizeSet?
    if @totalNumBytesInFile
      return true
    else
      return false
    end
  end

  def wholeFileSize # ltodo rename of full file
    assert @totalNumBytesInFile
    return @totalNumBytesInFile
  end

  def byteAlreadyReceived? byteNumStartZero # do we use this?
    # Say we have block size 5, we ask if 7 (8th byte) is written (byte 0-6 [7 of 'em total] has)
    # block = 1, offSet = 2
    # block.currentSize == 2
    # if offSet (2) < blockSize (2) # then ok
    blockNumber, offSet = calculateBlockAndOffset(byteNumStartZero)
    block = @allBlocks[blockNumber]
    if offSet < block.currentSize
      return true
    else
      return false
    end
  end

  def addDataOverall(incomingString, where, shouldReportToDHT = true)
    #at this point we  may not know how large the file is, so may need to create another block for it...
    stringToAdd = incomingString
    totalWritten = 0
    while stringToAdd
      blockToAddNumber, offSet = calculateBlockAndOffset(where)
      # check if this incoming chunk should be split into two blocks...
      assert @allBlocks.length > blockToAddNumber
      firstSection, stringToAdd = stringToAdd.shiftOutputAndResulting(@blockDefaultSize - offSet)# ltodo just keep track of where I am within the string, not creating new ones :)
      totalWritten +=  addDataToBlock(blockToAddNumber, firstSection, offSet, shouldReportToDHT)
      where += firstSection.length
    end
    # not necessarily true if we overwrite things assertEqual totalWritten, incomingString.length
    totalWritten

  end



  def calculateBlockAndOffset(byteNumber)
    assert byteNumber >= 0
    blockNumber = (byteNumber/@blockDefaultSize).to_i # truncate
    assert blockNumber < @allBlocks.length # yeah sure once failed here, blame it on switched streams
    offset = byteNumber - blockNumber*@blockDefaultSize
    assert offset >= 0
    return blockNumber, offset
  end

  def getBytesToReturnToPeerIncludingEndByte(startByte, endByte)
    assert startByte
    assert endByte
    assert endByte >= startByte
    if endByte - startByte > 100e6
      debug "warning asking for a lot of bytes! dangerous!"
    end
    # hope that it doesn't pull from too many blocks or we are toast again :)
    if endByte >= wholeFileSize
      error "ack got request for sending from #{startByte} to #{endByte} but I think my current end size is only #{wholeFileSize}, CONKING SEEDO"
    end
    assert endByte < wholeFileSize, "ack you want to get from #{startByte} to #{endByte} -- my size is only #{wholeFileSize}" # fails sometimes!
    ## ltodo let's see...how about block by block?
    amountWanted = endByte - startByte + 1
    amountGot = 0
    allOut = "" # ltodo make this more efficient--i.e. preserve the space, then just punch it in there
    while amountGot < amountWanted
      startBlock, startOffset = calculateBlockAndOffset(startByte + amountGot)
      assert startBlock
      assert startOffset
      # say you are at offset 10, you want 20 more, block size 15...you want 5
      amountInBlock = @allBlocks[startBlock].blockSize # could be less for the ending block
      assert amountInBlock
      amountInBlockPossible = amountInBlock - startOffset

      amountWantedFromBlock = [amountInBlockPossible, amountWanted - amountGot].min
      assert amountWantedFromBlock > 0
      toAdd = @allBlocks[startBlock].getBytes(startOffset, amountWantedFromBlock)
      allOut << toAdd # this could get bad for many blocks, large file, but as long as we only do it like 3 times, I guess we're ok --right now I think it only requestsa few 'next bytes to send' at a time, so we're ok.  a full 1G file, though...yikes :)

      amountGot += amountWantedFromBlock
    end

    return allOut

  end


  def done?
    if  @already_finalized
      debug "done? called after finalize was already called! returning we are done, ok? --possible if the p2p server calls it during finalize, which it does"
      return true
    end
    if not @allBlocks
      debug " asked block keeper if file was done downloading without starting up the blocks (knowing size of file...) returning without checking any for now"
      return false
    end
    success = true
    dbg if File.exist? 'stop_now2'
    @allBlocks.each_with_index do |block, index|
      if not block.done?
        #print "!DONE #{index}/#{@allBlocks.length} #{@peerCountTokens} #{block.to_s2}\n"
        success = false
      else
        #print "d#{@peerCountTokens}"
      end
    end
    print("status #{@status}")
    return success
  end

  def to_s
    returnVal =  "Blocks:"
    for block in @allBlocks
      returnVal +=  block.to_ps
    end
  end

  def next_finishing_byte_done_after this_byte # for now this is pretty tightly asserted as being just 'from where we are' on
    if !@allBlocks
      assertEqual this_byte, -1
      return -1
    end

    unless this_byte == -1 # which would be like the starting case, so for sure we know we have 'written' that byte
      old_byte_block = @allBlocks[this_byte/@blockDefaultSize]
      byte_within_block = this_byte % @blockDefaultSize
      assert old_byte_block.currentSize >= (byte_within_block + 1), "what we aren't there yet even!"
    end
    for block in @allBlocks[(this_byte + 1)/@blockDefaultSize..-1] do
      if !block.done?
        block_at, block_end = getFirstUnwrittenByteInBlockAsNumberFromBeginningAndEndByteOfBlockInclusive(block.blockNumber)
        return block_at - 1
      end
    end
    assert done?
    return wholeFileSize() - 1
  end

  def getFirstUnwrittenByteInBlockAsNumberFromBeginningAndEndByteOfBlockInclusive(blockNumber)
    block = @allBlocks[blockNumber]
    return block.getStartingNonFinishedByteWithinBlock() + block.blockNumber*@blockDefaultSize, block.blockNumber*@blockDefaultSize + block.blockSize - 1 # not too big is right
  end

  def add_global_peer peer
    debug 'not adding global peer'
    return # disabled :)
    debug 'add global' + peer.inspect
    for block in @allBlocks
      block.add_peer_if_useful peer
    end
  end

  def p2pStateChangedAll
    for block in @allBlocks do
      block.p2pStateChanged
    end
  end



end # class

require 'lib/utilities_block_manager.rb' # just for the testing we do internally :)

# ltodo ruby-prof at home against apache, with smaller blocksizes, etc.
#==========================================================================================
class Block

  def initialize(blockSize, number, url, uid, logger, urlHost, urlPort, blockManagerParent)
    @blockManagerParent = blockManagerParent
    assert number && url && uid && logger && blockSize
    @logger = logger
    @urlHost = urlHost
    @urlPort = urlPort
    @fullUrl = url
    @blockSize = blockSize
    @alreadyReportedDoneToDHT = false
    @blockNumber = number
    assert @blockNumber
    @log_prefix = "block #{@blockNumber}"
    @filename = ("/tmp/blocks/#{url[0..20].sanitize}_number_#{number}_uid_#{uid}.block")
    assert( !File.exists?(@filename)) # that would be bad :)
    @writeMutex = Mutex.new
    # touch it
    begin
      file = File.new(@filename, "w")
      file.close
    rescue Errno::EMFILE # don't know what linux equivalent is
      error "arrr! unable to open a file for a block to live in! aborting!"
    end
    assert File.exists?(@filename)
    @sumWithinBlock =  0
    @peerCountTokens = 0
    @amGettingFromDHT = false
    @peerPossibilities = []
    @peersTried = {}
    @peersInUse = {} # ltodo use this instead of peerCountInuse
    @next_round_number = 0
  end
  include Logs
  attr_reader :blockNumber
  attr_accessor :alreadyReportedDoneToDHT # ltodo used?
  attr_accessor :blockSize
  attr_accessor :peerCountTokens # ltodo take out

  def add_peer_if_useful(peer)
    @peerPossibilities << peer unless @peerPossibilities.include?(peer) or @peersTried.include?(peer) or ( peer[0] == @blockManagerParent.localIP and peer[1] == @blockManagerParent.p2pServer.port) # don't add ourselves
    @peerPossibilities = @peerPossibilities.randomizedVersion
  end

  # used if you have a peer that returns a few useless bytes, we mark it for destruction as useless, then it starts returning good bytes, but then, since we marked it for destruction, it ends its block early--we want to reuse them!
  def reinsert_peer(ip, port)
    assert @peersTried.delete([ip, port])
    @peerPossibilities.unshift [ip, port] # put it at the front
    p2pStateChanged
  end

  def delete_all_tokens_and_shutdown_peers
    kill_origin_if_going
    @peerCountTokens = 0
    @peersInUse.each{|peer, true_val| peer.shutdown_once_without_writing }
  end

  def addToken
    @peerCountTokens += 1
    debug "added token--tokens now at #{@peerCountTokens}"
    p2pStateChanged
  end

  def to_s2
    ''#"block p2p state: tokens #{@peerCountTokens}  [#{@blockManagerParent.total_peer_token_count_globally} total tokens]done? #{'false for now'} peers in use #{@peersInUse.map{|peer| peer.to_s}.inspect} possibilities waiting #{@peerPossibilities.inspect}, used #{@peersTried.map{|p| p.to_s}.inspect}"
  end
  @@max_connections_to_a_peer = 1 # only want to download one block at a time, from a peer...i.e. only one connection to each peer we know about
  # regardless of how many blocks they have [to get each block faster]
  def p2pStateChanged
    debug "p2pstate changed -- finalized is #{@already_finalized_block}"
    if @am_interrupted_state or @blockManagerParent.already_finalized
      # don't want to start any origins or any peers if this is the case!
      assert @peerCountTokens == 0, "we should have deleted them all if we shut down" if @am_interrupted_state
      return
    end

    if done?
      # I assume this should happen when a block finishes???
      if @peerCountTokens > 0
        error "giving away some weird extraneous tokens #{@peerCountTokens}" # ltodo cleaner somehow or other, delete this line -- necessary for now, though.
        # ltodo get from coral, google's cache (!), codeen
        finalize_block # just in case
      end
      return
    end

    if @peerCountTokens == 0
      debug "got some pre existing peers (I presume) from the early pre emptive query -- they were added, or another peer finished with a peer and wanted to release it to do more blocks now"
    end

    if @peerCountTokens > @peersInUse.length
      numPeersWanted = @peerCountTokens - @peersInUse.length
      if @peerPossibilities.length < numPeersWanted
        # we don't want to actually do this, though, to reserve a port for the origin should it want help
        # attempt_to_get_more # will ALWAYS have to get more if this is the case
      end

      non_used_possibilities = []
      for peer in @peerPossibilities.reverse do
        unless @blockManagerParent.peers_in_use_for_various_blocks_counter[peer] and @blockManagerParent.peers_in_use_for_various_blocks_counter[peer] >= @@max_connections_to_a_peer
          non_used_possibilities << peer
        else
          debug "ignoring a peer #{peer} for now -- they're too busy!"
        end
      end

      if @peerPossibilities.length > 0
        [numPeersWanted, non_used_possibilities.length].min.times do # doesn't account for non firing peer
          possibility = non_used_possibilities.shift # shift is newer [?] -- random might be best, though ltodo
          @blockManagerParent.peers_in_use_for_various_blocks_counter[possibility] ||= 0
          @blockManagerParent.peers_in_use_for_various_blocks_counter[possibility] += 1
          @peerPossibilities.delete_if {|b| b == possibility}
          @peersTried[possibility] = true
          log "trying peer #{possibility.inspect}"
          begin
            EM::connect(possibility[0], possibility[1], GenericGetFromSinglePeer) { |conn|
              @peersInUse[conn] = true
              conn.init @fullUrl, @blockManagerParent, nil, nil, nil, @logger, "p2p p2p", possibility[0], possibility[1], @blockNumber, @peerThreadNumber, proc {|retval|
                @peersInUse.delete(conn)
                one_peer_finished(retval)
                @blockManagerParent.peers_in_use_for_various_blocks_counter[possibility] -= 1
                @blockManagerParent.p2pStateChangedAll # notify everyone :) ltodo just notify those that have registered as wanting it lol
              }

            }
          rescue RuntimeError
            error 'EM connect FAILED connecting to peer'
            # assume the problem is on their side so don't reconnect -- sane # @peersTried.delete(possibility)
          end
        end
      end
    end
    assert !done?
    if @peersInUse.length == 0
      start_origin_unless_already_running
    else
      #debug 'at least one peer is going, so killing origin'
      #kill_origin_if_going # I think we don't want this since the origin might give us some good stuff in the meantime.  Let its uselessness kill it
    end

    if @peersInUse.length < @peerCountTokens
      attempt_to_get_more # do this at the end to save on file descriptors (believe it or not)
    end
  end

  def to_s
    return @blockNumber.to_s + "(#{currentSize}/#{@blockSize})"
  end

  def kill_origin_if_going
    if @origin_conn
      debug 'shutting down origin for some reason'
      @origin_conn.shutdown_once_without_writing
    else
      debug 'origin isnt going, so not killing it'
    end
  end

  def start_origin_unless_already_running
    unless @origin_conn
      return if @am_getting_origin
      @am_getting_origin = true
      begin
        EM::connect(@urlHost, @urlPort, GenericGetFromSinglePeer) { |conn|
          conn.init @fullUrl, @blockManagerParent, nil, nil, nil, @logger, "p2p cs origin", @urlHost, @urlPort, @blockNumber, @peerThreadNumber, proc {|retval| origin_done(retval)}
          @origin_conn = conn
          @am_getting_origin = nil
        }
      rescue RuntimeError => e
        error "ack origin ERRED? weird! unexpected #{e}"
        @origin_conn = nil
      end
    end
  end

  def attempt_to_add_from_dht(status, values, pm, round)
    debug "got #{status} #{values} round #{round}"
    if status == :success # assume they ain't lyin' -- should work unless it is lying when it says none and "success"
      if round == @current_round_in_flight
        debug "got back an openDHT 1st success for round #{round} -- adding them, setting it to 'go' again at some point"
        if pm.is_text?
          debug 'since it had a pm, setting it to go again immediately'
          @current_round_in_flight = nil
        else
          debug 'since it had no pm, setting it free in...1s'
          @current_round_in_flight = :will_soon_be_reset # save it away so the next few successes don't confuse themselves as being the first :)
          EM::Timer.new(1) {@current_round_in_flight = nil;  debug 'setting it free for a new round -- you might see this late, as we dont accomodate for it in close--its the DHT re-get timer'; p2pStateChanged}
        end

        # now add to the peers available list
      else
        debug "got back an old opendht round -- just adding them"
      end
      for value in values
        assert value
        host, port, version = value.split(':')
        new_peer = [host, port.to_i] # ltodo an 'old peers' one so we don't re-add them!
        if @peerPossibilities.include? new_peer or @peersTried[new_peer]
          "skipping redundant already known about peer #{host} #{port}"
        else
          log "adding new peer #{host} #{port}"
          add_peer_if_useful new_peer
        end
      end
      @peerPossibilities = @peerPossibilities.randomizedVersion

      p2pStateChanged # yep -- dht came back, possibly added some more peers, and maybe should start again
    else
      debug "got back a failure for round #{round}"
      if round == @current_round_in_flight
        @number_failed_current_round += 1
        if @number_failed_current_round == @blockManagerParent.opendht.total_get_responses_expected
          @current_round_in_flight = nil
          error "done with this whole round from failure opendht! arr!! will restart and try opendht again in 1s..."
          EM::Timer.new(1, proc { p2pStateChanged } ) # yep -- dht failed and finished, maybe should start again
        end
      else
        debug "got an error from in flight round, waiting for others to come back"
      end
    end
  end

  def attempt_to_get_low_key
    attempt_to_get_more 1, 1
  end

  def attempt_to_get_more key_split_to_request_all_simultaneously = nil, repeat_all_keys_this_many_times = nil
    if !@current_round_in_flight
      @current_round_in_flight = @log_prefix + (' get round' << @next_round_number.to_s)
      @next_round_number += 1 # keep it unique :)
      @number_failed_current_round = 0
      @blockManagerParent.opendht.get_array(self_dht_key, @current_round_in_flight, proc {|status, values, pm, round, key_used| attempt_to_add_from_dht(status, values, pm, round)}, @log_prefix, key_split_to_request_all_simultaneously, repeat_all_keys_this_many_times)
    else
      debug "already have a dht request out, don't worry--its round is #{@current_round_in_flight}"
    end
  end

  def origin_done status
    debug "origin's done: #{status}"
    process_peer_result status, :origin
    time_to_wait = 1
    time_to_wait = 0 if done?
    debug "restarting to origin [if necessary] in #{time_to_wait}s"
    EM::Timer.new(time_to_wait) { @origin_conn = nil; p2pStateChanged } # have it restart that origin peer, if necessary, but not immediately :)
  end

  def process_peer_result status, cs_or_p2p
    if status == :success
      debug "#{cs_or_p2p} said success for that block get"
      assert done?
      finalize_block
    else
      debug "#{cs_or_p2p} said fail for that block get--could be too slow, or unbound too early"
    end
  end

  def one_peer_finished status
    debug "peer done #{status}"
    process_peer_result status, :peer
    p2pStateChanged # restart the next peer (or itself) if necessary
  end

  def finalize_block # ltodo rename something else more intuitive
    assert done?
    if @already_finalized_block
      debug "called finalize on a block twice!? possible if several peers all think they got the last byte, or if CS finished and told the p2p's to give up :)"
      return
    end
    @already_finalized_block = true
    kill_origin_if_going
    @blockManagerParent.addP2PTokens @peerCountTokens # give them away, if we have any--conveniently placed at the top in case some weirdness brings some extras here :)
    delete_all_tokens_and_shutdown_peers
  end

  def delete_internal_file
    assert @filename
    assert File.exists?(@filename)
    begin
      File.delete(@filename)
    rescue Errno::EACCES
      error "tried to delete #{@filename} failed.  This stinks."
    end
    @filename = 'deleted_file'
  end

  def getAllWritten
    return getBytes(0, currentSize)
  end

  def validData?
    if not done?
      @logger.error "ack called validdata on an undone block! will test its contents anyway" + to_s
    end
    return BlockManager.verifyChunk(getAllWritten, @blockNumber*@blockManagerParent.blockDefaultSize, @logger) # ltodo clean
  end

  def setNewSize(thisManyBytes)
    # only called on the last block to keep it the right size
    assert thisManyBytes > 0
    assert thisManyBytes <= @blockSize # ltodo rename @@blockSize
    @blockSize = thisManyBytes
    #    createBlockTrackers
  end

  # ltodo split it into sub blocks, etc.
  def writeToFileObject(toThisFile)
    if not done?
      @logger.error "writing from paritally done block"
    end
    toThisFile.write(getAllWritten)
  end

  def firstUnfilledByte
    return currentSize
  end

  def currentSize
    assert @sumWithinBlock
    return @sumWithinBlock
  end

  def done?
    if not @filename
      @logger.error "weird asking a block if its done--it hasn't started (had a created file or at least a set filename) even!"
      return false
    end
    assert currentSize <= @blockSize, "TOO BIG currentSize #{currentSize}  > blocksize #{@blockSize}"
    #print "my size is not complete: #{currentSize}/#{@blockSize} tokens--#{@peerCountTokens} " unless currentSize == @blockSize
    return currentSize == @blockSize
  end

  def getStartingNonFinishedByteWithinBlock # within a block
    return currentSize
  end

  def self_dht_key
    assert @fullUrl && @blockNumber
    "#{@fullUrl}_peers_for_block_num_#{@blockNumber}"
  end

  def self_dht_value
    "#{@blockManagerParent.localIP}:#{@blockManagerParent.p2pServerPort}:v#{$version}"
  end

  def set_block_done_in_dht
    @still_setting = true

    @blockManagerParent.repeat_add_until_done(self_dht_key, self_dht_value, :round_id => @log_prefix + ' set round', :description => @log_prefix) {|status, values, pm, round, key| done_setting }
  end

  def done_setting
    @still_setting = nil
    if @want_to_remove_after_setting # ltodo do we wait for all keys to set?
      debug "doing late remove from dht"
      remove_from_dht
    end
  end

  def remove_from_dht
    if $PRETEND_CLIENT_SERVER_ONLY
      debug "NOT doing open dht remove as we're CS only...kind of!"
    else
      if @still_setting
        debug "deferring remove from dht till setting is done"
        @want_to_remove_after_setting = true # do it later
      else
        @want_to_remove_after_setting = nil
        @blockManagerParent.opendht.remove(self_dht_key, self_dht_value, :description => @log_prefix + ' remove round')
      end
    end
  end

  def calculateHash
    assert done?
    return "fakedeadbeef" # ltodo
  end

  def addToMe(what, offsetBytesStart)
    @writeMutex.synchronize {
      newSize = nil
      oldSize = nil
      assert offsetBytesStart
      if (what.length + offsetBytesStart > @blockSize)
        error "weird received more than the sum of the block! what?!"
        raise "you stink! that's poor addition to the block!"
      end
      if $verifyIO
        assert BlockManager.verifyChunk(what, @blockNumber*@blockManagerParent.blockDefaultSize + offsetBytesStart, @logger), "JUST RECEIVED CORRUPTED DATA!"
      end # tlodo writeup possible optimization is...is...get block 0 ja [no real help, though]
      endOfThisAddition = offsetBytesStart + what.length
      if offsetBytesStart != currentSize
        output = "Potentially overwriting written bytes! block #{@blockNumber} my current download size is #{currentSize} and you want to write #{what.length}B @ #{offsetBytesStart} leaving it at #{endOfThisAddition}"
        if endOfThisAddition > currentSize
          @logger.debug output + "...allowing anyway--it gives us some useful stuff.."
        else
          @logger.debug output + " ignoring it! useless!"
        end
      end
      oldSize = newSize = amountAddedThisTime = nil
      if endOfThisAddition > currentSize # then this addition is useful to us

        if offsetBytesStart > currentSize
          error "ack!!! we want to write at #{offsetBytesStart} and currentEndStarting from here size is #{currentSize} attempting to continue gracefully..."
          return 0
        end
        assert offsetBytesStart <= currentSize
        oldSize = currentSize
        if oldSize == offsetBytesStart
          assert @filename
          count = 1
          File.append_to @filename, what
        else
          debug 'overwriting block file TODOR fix this'
          oldFile = File.new(@filename, "r")
          oldFileContents = oldFile.read
          oldFile.close
          oldFileContents[offsetBytesStart, offsetBytesStart + what.length - 1] = what
          newFile = File.new(@filename, 'wb') # re-write it. yuck ltodo do this better!
          newFile.write(oldFileContents)
          newFile.close
        end
        amountAddedThisTime = endOfThisAddition - oldSize
        # update currentSize
        @sumWithinBlock = endOfThisAddition # ltodo replace currentSize with @sumWithinBlock, or replace this with a function, right here
        newSize = currentSize
      else
        return 0
      end

      if oldSize == offsetBytesStart
        if newSize != oldSize + what.length
          error "weird"
        end
        assert newSize == oldSize + what.length, "file size changed in write!!"
      end
      assert newSize
      assert @blockSize
      assert newSize <= @blockSize, "newly set size of #{newSize} > total for block of #{@blockSize} after adding length #{what.length} at #{offsetBytesStart} of #{what}"
      return amountAddedThisTime
    }
  end

  def getBytes(offset, howMany)
    assert offset + howMany <= @blockSize
    out = ""
    assert @filename, "no filename for retrieving bytes from???"
    out = File.read_from @filename, howMany, offset
    assertEqual out.length, howMany, "apparently the file didn't have enough bytes for us? a read of size #{howMany} at positio n#{offset} with size #{currentSize} #{File.lstat(@filename).pretty_inspect} " # ltodo when you are waiting for file size, try two at once :)
    return out
  end

  def getByte(offset)
    assert offset < currentSize
    return getBytes(offset, 1)[0] # returns a char ltodo test
  end

end # class


class FixNumExclusive
  def initialize toThisNumber
    @writeMutex = Mutex.new
    @actualNumber = toThisNumber
  end
  # ltodo maybe subblocks are too arbitrary--just keep track of what has been written in a list, divide 'em :)
  def addExclusive thisNumber
    @writeMutex.synchronize { # vltodo is this too big a hit?
      @actualNumber = @actualNumber + thisNumber
    }
  end

  def func= toThis
    @writeMutex.synchronize { @actualNumber = toThis }
  end

  # ltodo note with error when ack overwriting...

  def to_s
    return @actualNumber.to_s # ltodo more of a queue 'wait for outstanding to finish first... :)'
  end

  def to_i
    return @actualNumber.to_i
  end
end

if $0 == __FILE__ or debugMe('block_manager')
  BlockManager.timeSelf
  BlockManager.testSelf
end
