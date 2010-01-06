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

end
