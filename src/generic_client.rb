#!/usr/bin/ruby
# Roger's client per connection
require 'constants'
require 'pp'
require 'lib/timeKeeper.rb'
require 'timeout'
require 'listener.rb'
require 'eventmachine'
# ltodo experiment with 'large' chunks from EM
# ltodo could also examine why so much waste in incoming/outgoing using this here system of transport between itself
# ltodo with HEAD we could totally use that to start the connection, not be a HEAD.
class GenericGetFromSinglePeer < EventMachine::Connection
  # ltodo have files with same blocks cache them at same place when they're complete...if I want tons downloading very very large files...hmm...
  def init fullUrl, blockManager, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, logger, p2pOrCSType, peer_host, peer_port, blockNumber = nil, peerCountNumber = nil, terminateWithStatusProc = nil
    self.set_comm_inactivity_timeout 30# # after awhile why keep it?
    #self.set_comm_inactivity_timeout  TEST_TIMEOUT if Socket.gethostname =~ /roger/i or Socket.gethostname == "melissa-pack"
    @logger = logger
    @fullUrl = fullUrl
    @terminateWithStatusProc = terminateWithStatusProc
    assert ['cs straight', 'p2p p2p', 'p2p cs origin'].include?(p2pOrCSType)
    @p2pOrCS = p2pOrCSType
    @blockNumber = blockNumber
    @peerCountNumber = peerCountNumber
    @gotFirstByte = false
    @connection_completed = false
    @amPastHeader = false 
    # ltodo assert their response endbyte is my request endbyte :)
    @blockManager = blockManager
    @blockManager.allOutGoingConnections[self] = true
    @parent = @blockManager
    assert peer_host
    assert peer_port
    @peersHostname = peer_host
    @peersPort = peer_port
    @log_prefix = "#{@p2pOrCS} download #{'block ' + @blockNumber.to_s if @blockNumber} [#{@peersHostname}:#{@peersPort} => my:??]: "
    log 'start'
    @dWindowSeconds = dWindowSeconds
    if @blockNumber
      @startByte, @endByte = @blockManager.getFirstUnwrittenByteInBlockAsNumberFromBeginningAndEndByteOfBlockInclusive(@blockNumber)
    else
      @startByte = 0 # ltodo later case of a CS that just gets interrupted early...
      debug "using start byte of 0 for CS"
      assertEqual @p2pOrCS, "cs straight"
      @endByte = nil
    end
    @total_bytes_received = 0 
    if dRIfBelowThisCutItBps
      assert dRIfBelowThisCutItBps > 0, "dR must be nil or > 0"
      assert dWindowSeconds && dWindowSeconds > 0, "dW must be > 0"
      @receivedHistory = TimeKeeper.new(@logger) if dRIfBelowThisCutItBps
      lastTimeChecked = Time.now
      resolution = [0.2, dWindowSeconds].min
      @check_dRProc = proc {
        return if (Time.now - lastTimeChecked) < resolution
        return if @alreadyShutdown
        lastTimeChecked = Time.now
        currentRate = @receivedHistory.calculateSpeedBytesPerSecond dWindowSeconds
        if currentRate < dRIfBelowThisCutItBps
          log "GOING TO P2P TOO SLOW dR with our rate #{currentRate}/#{dRIfBelowThisCutItBps} (dW #{dWindowSeconds}" # we don't reschedule the dR timer here
          shutdown_once_without_writing # the easiest way out, though gross
        else
          time_when_could_fail = @receivedHistory.timeBeforeCouldFallBelow dRIfBelowThisCutItBps, dWindowSeconds
          log "passed dR with rate #{currentRate}/#{dRIfBelowThisCutItBps}, rescheduling in #{time_when_could_fail}s"
          EM::Timer.new(time_when_could_fail + 0.01, @check_dRProc) # ltodo could avoid creating new classess...eh we got GC :)
        end
      } 
    end
    
    # add a one shot
    # turns out this next line is very dangerous--a central server under high load waits...lots
    # dTToWaitAtBeginning ||= 20 # dude if a peer waits more than 20--he's gone
    @checkDTTimer = EM::Timer.new(dTToWaitAtBeginning, proc { 
      if @alreadyShutdown
        debug "dT (first byte?#{@gotFirstByte} is actually even being ignored as already closed for some reason"
        return
      end
      
      if !@gotFirstByte
        log "failed dT gauntlet of #{dTToWaitAtBeginning}--moving on to p2p or past this peer"
        shutdown_once_without_writing
      else
        assert false, "we no longer get here we cancel it on first byte!"
      end
    }) if dTToWaitAtBeginning
    pageStringOnly, hostToGetFrom, ipPortToGetFrom = TCPSocketConnectionAware.splitUrl(fullUrl)
    @urlHostNameOnly = hostToGetFrom
    @urlPortNumberOnly = ipPortToGetFrom.to_i
    @urlSubPageOnly = pageStringOnly
  end
  
  def to_s
    @log_prefix
  end
  
  def connection_completed
    info = get_tcp_connection_info_hash
    @log_prefix = "#{@p2pOrCS} download #{'Block ' + @blockNumber.to_s if @blockNumber} [#{@peersHostname}:#{@peersPort} => my:#{info[:local_port]}]: "
    log "#{@p2pOrCS} connected to peer"
    @connection_completed = true 
    if @blockNumber
      @startByte, newEnd = @blockManager.getFirstUnwrittenByteInBlockAsNumberFromBeginningAndEndByteOfBlockInclusive(@blockNumber)
      assertEqual newEnd, @endByte, 'expected to be the same'
    end
    
    if @blockNumber and @startByte > @endByte
      debug "guess this was a late peer attempt here--block seems done before connection completed even"
      shutdown_once_without_writing # will still report success on unbind...which is kind of expected, but weird. ltodo
      return
    end
    
    if @alreadyShutdown
      debug "wow conn completed after dT failed or otherwise shutdown--closing"
      close_connection
      return
    end
    @whereAt = @startByte
    requestString = TCPSocketConnectionAware.createHTTPRequest(@urlSubPageOnly, @urlHostNameOnly, @urlPortNumberOnly, @startByte, @endByte) # NOTE we don't send the @endByte, but let it stream as much as it wants :) ltodo if you do this again, we should 'stream' as it comes in or what?
    send_data requestString
    debug "sent (JIT) request (#{@whereAt} -> #{@endByte})"
  end
  
  def gotFirstByte
    if @checkDTTimer
      @checkDTTimer.cancel # ltodo rename explode dT :)
      # ltodo maybe move this code out or subclass it
      log "passed dT!" if @checkDTTimer
      debug "starting dr [and its window] now!"
      EM::add_timer(@dWindowSeconds) { @drTimer = EM::PeriodicTimer.new 0.2, @check_dRProc if @check_dRProc and !@alreadyShutdown} if @check_dRProc
    end
    @gotFirstByte = true
  end
  
  def receive_data m
    assert m.length > 0, "I assume EM doesn't pass us empty packets"
    @total_bytes_received += m.length
    log "just received #{m.length}B (raw)"
    if !@gotFirstByte
      gotFirstByte
    end # ltodo calc. wasted downloaded bytes per peer
    
    @receivedHistory.addToHistoryWindow(m.length) if @receivedHistory
    useful = nil
    if !@amPastHeader
      useful = true # the interesting side effect of this is counting only their first full block of data as 'is it competitive' ltodo think about
      amPastHeader, newData, currentTransmissionSize, totalFileSize = TCPSocketConnectionAware.parseReceiveHeader m
      @amPastHeader = true if amPastHeader
      if currentTransmissionSize or totalFileSize
        if not @blockManager.fileSizeSet?
          error "I thought I didn't have to set it to this!" unless @p2pOrCS == "cs straight"
          totalFileSize ||= currentTransmissionSize # this has some conflict with the TCPSocketConnectionAware stuff...hmm...
          debug "header totalFileSize #{totalFileSize}" # ltodo we don't take into account 404's
          shutdown unless totalFileSize
          return unless totalFileSize
          @blockManager.setFileSize(totalFileSize)
          @endByte ||= totalFileSize - 1
        end
      end
      assert @blockManager.fileSizeSet? if @amPastHeader
      if !@endByte and !@amPastHeader
        assert @total_bytes_received < 1000, "how can you not have an endByte given in headers yet? [#{m}]"
      end
      m = newData
      return unless @amPastHeader 
    end
    useful_new_data = @blockManager.addDataOverall(m, @whereAt, !$PRETEND_CLIENT_SERVER_ONLY)
    useful ||= (useful_new_data > 0)
    
    if useful_new_data > 0
      debug "rec eived (useful) #{useful_new_data} B/#{m.length} received :([my]#{@whereAt}=>#{@whereAt + m.length - 1}/#{@endByte}). Total for file #{@blockManager.totalBytesWritten}/#{@blockManager.wholeFileSize}, original request was for #{@startByte} - #{@endByte}"
      @last_receipt_was_useful = true
    end
    
    @whereAt += m.length
    if (@whereAt >= @endByte + 1)
      if @blockManager.done?
        log "(early) DONE WITH WHOLE FILE #{@p2pOrCS}"
        @blockManager.report_done
      end
      log "done receiving or block done #{@whereAt}/~#{@blockManager.blockDefaultSize}"
      shutdown_once_without_writing # let the useless guy handle it--or the server ltodo add in a connection-close or something
      # or check if we actually set the 'right' endByte so we can certify this! have two endbytes ltodo so there's this conflict here between 'lets get on with the peer' or what not...might lead to some forking.  moving on 'fast' which we can do with @endByte is...ok I guess, especially if we did specify an end byte, so I'd say do it if we get THEIR endbyte
    end
    
    if !useful
      @marked_as_wasteful_once = true
      @last_receipt_was_useful = false # currently I'm not sure if we use the last_receipt_was_useful stuff
      log "received some not useful [at least this one read was]"
      debug "wasted input/write of #{m.length}"
      if @p2pOrCS.include? 'cs'
	debug "closing connection with origin for wasted bytes--we want to be as nice as possible to the origin, really ltodo: when we first receive a byte that precludes the origin close it"
        shutdown_once_without_writing
      else
 	debug "NOT closing this connection -- we'll live with the extra bytes coming in since we are HUNGRY for bytes, for now"
      end
    end
    
  end
  
  def shutdown_once_without_writing
    if @alreadyShutdown
      return
    else
      @alreadyShutdown = true
    end
    debug "generic shutdown calling out and back, my transfer status:#{@whereAt}/#{@endByte ? @endByte + 1 : '?'} (might be over if we don't send endByte)"
    if @terminateWithStatusProc
      if @endbyte and (@whereAt >= (@endByte + 1))
        debug "straight success passout"
        @terminateWithStatusProc.call(:success)
      else
        if @endByte and @blockManager.byteAlreadyReceived?(@endByte - 1)
          debug "success since somebody else was successfull--that's success enough for me! and allows them to receive late and really not mark it and things continue on right--otherwise we report failure, start another one, which might request nothing, etc., and maybe not note the file is done -- note this lags slightly" # ltodo
          @terminateWithStatusProc.call(:success)
        else
          debug "failure passout"
          @terminateWithStatusProc.call(:failure)
        end
      end
    end
    
    if @drTimer
      @drTimer.cancel
      debug "cancelled dr"
    end
    
    if @checkDTTimer
          @checkDTTimer.cancel 
          debug 'cancelled dt'
    end
    
    close_connection # without writing
    @blockManager.allOutGoingConnections.delete(self) # we're done from the semi global list. ltodo should it be here?
    
  end
  
  def unbind
    debug "unbind called last receipt useful: [#{@last_receipt_was_useful}] marked as wasteful once: [#{@marked_as_wasteful_once}] type [#{@p2pOrCS}]"
    if @p2pOrCS == 'p2p p2p' and @last_receipt_was_useful and @marked_as_wasteful_once # then we weren't really wasteful and have poorly judged a peer for this block!
      error 'adding back in a peer as useful, as he started poor then caught up! change to debug on sight'
      @parent.reinsert_peer @peersHostname, @peersPort, @blockNumber # ugh
    end
    log "bad peer!! -- connection never even completed" if !@connection_completed
    shutdown_once_without_writing
  end
  
  include Logs 
  
end
