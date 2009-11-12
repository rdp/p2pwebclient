#
# ltodo Fix the X axis labels on the graphs (make them pretty).
# ltodo make a new vary_parameter graph (use numbers from single run objects) for end method/style

# ltodo I once ran test6 and it erred with 'run already exists!' tut tut 
# ltodo add 'connection:close' to these
# ltodo cull threads more often in this one
require 'constants'

# ltodo test that it re-picks a new port on port in use :)
class Thread
  attr_accessor :outSocket
end

class P2PServerConnection < EventMachine::Connection
  attr_accessor :serverNumberedCount # allow it to set this up in the block
  attr_accessor :port
  attr_accessor :logger
  attr_accessor :blockManager
  attr_accessor :speedLimitPerConnectionBytesPerSecond
  attr_reader :serverShouldStop
  attr_reader :aliveServerObjects
  
  def post_block parent
    @parent_server_wrapper = parent
    @parent = parent # for logs to work
    # ltodo don't have it set the vars like it does :)
    info = get_tcp_connection_info_hash
    @log_prefix = "#{info[:local_host]}:#{info[:local_port]}=>#{info[:peer_host]}:#{info[:peer_port]} #(#{@serverNumberedCount})"
    if info[:local_port] != @port
      error "ack port discrepancies #{info.inspect}  != #{@port}"
    end
    self.set_comm_inactivity_timeout 60*3 # after awhile why keep it? ltodo stinky reuse 60*3
    self.set_comm_inactivity_timeout  TEST_TIMEOUT if Socket.gethostname == "Rogers-little-PowerBook.local" or Socket.gethostname == "melissa-pack"
    debug "got a peer incoming connection. Current load number is #{@parent_server_wrapper.aliveServerObjects.length}"
    if @speedLimitPerConnectionBytesPerSecond
      debug "speed limiting it to #{@speedLimitPerConnectionBytesPerSecond}Bps"
      @speedLimiter = TimeKeeper.new(@logger)
      speedLimitMutex = Mutex.new
      startLimit = Time.new
    end
    
    if @parent_server_wrapper.serverShouldStop
      error "got a late peer! closing socket... (not expected)"
      close_connection
    end
  end
  
  include Logs 
  
  def unbind
    assert @parent_server_wrapper.aliveServerObjects.delete(self)
    if @received_data_request 
      @sender_proc_wrapper.cancel
      if @queued_all
        debug "SERVER CONN done totally normally -- total count now #{@parent_server_wrapper.aliveServerObjects.length}"
      else
        debug "SERVER CONNdone only half way through"
      end
    elsif @received_head_request
      # pass
    else
      error "SERVER CONN done without receiving any request! Weird"
    end
  end
  
  def getWholeFileSize
    assert @blockManager.fileSizeSet?
    @blockManager.wholeFileSize
  end
  
  # ltodo logger when in production mode say nothing :) [constants]
  def receive_data requestIncoming
    # ltodo time these conns out, esp. if I receive nothing
    close_connection && return if @blockManager.already_finalized
    file, host, port, startByte, endByte, type, fullUrl = TCPSocketConnectionAware.parseHTTPRequest(requestIncoming) # assume it's a request
    if !file
      debug "Unable to parse request [#{requestIncoming}] -- giving up. Thread count #{@parent_server_wrapper.aliveServerObjects.length}"
      close_connection # I must presume this terminates us :)
    end
    
    if file != @blockManager.urlFileName
      fullUrl = "http://#{host}:#{port}#{file}" # ltodo look into this--is this necessary?
        if @parent_server_wrapper.serveAnyRequest and file and host and port
          error "within the fake server got request for url #{fullUrl} (not current/starting #{@blockManager.urlFileName}) continuing==possibly in error!" # ltodo
        else
          error "got request for generically WRONG FILE (or bad HTTP request)-- kicking out early their requested file #{file}, is not #{@blockManager.urlFileName} request #{requestIncoming} TURFING"
          close_connection
          return
        end
    end    
    
    if !startByte 
      assert !endByte
      startByte = 0
      debug "guessing full file start #{startByte} end #{endByte} request for whole file"
    end
    endByte ||= @blockManager.wholeFileSize - 1
    assert startByte <= endByte
    log "got #{type} request for file #{file} port #{port} startByte #{startByte} endByte #{endByte}"
    header = TCPSocketConnectionAware.createReturnHeader(startByte, endByte, getWholeFileSize())
    assert header.length > 0
    send_data header
    debug "wrote reply header length #{header.length} for type #{type}"
    if type == "HEAD" # then we're done
      @received_head_request = true
      debug "wrote head of file size #{getWholeFileSize()}! -- closing!"
      close_connection_after_writing
      return
    end
    @received_data_request = true
    how_often_check_queue_in_seconds = 0.15#S
    chunkSize = 4_000_000*how_often_check_queue_in_seconds # 4 MB/S max empirically this is only like 1.5MB/s serving speed
    if @speedLimitPerConnectionBytesPerSecond
      how_often_check_queue_in_seconds = 1
      chunkSize = [@speedLimitPerConnectionBytesPerSecond, chunkSize].min
    end
    debug "using chunkSize #{chunkSize} every #{how_often_check_queue_in_seconds}s"
    nextByteToSendWithinRequest = startByte
    @dropped_me = false
    send_proc = proc { ||
      if @dropped_me
        return # never send again :)
      end 
      if @parent_server_wrapper.serverShouldStop
        debug "not sending any more-- parent said we should stop!" # ltodo cancel these, too, so we don't get weird late logging messages
        return
      end
      assert nextByteToSendWithinRequest <= (endByte + 1)
      return if nextByteToSendWithinRequest == endByte + 1
      outbound_queue = get_outbound_data_size
      debug "outbound size is #{outbound_queue}" # ltodo make this have its own call
      if outbound_queue > chunkSize/2
        debug "not sending anymore for now"
        return
      else
        debug "sending more"
      end
      start_send_time = Time.now
      lastByteWithinChunk = [endByte, nextByteToSendWithinRequest + chunkSize - 1].min
      
      nextToWrite = @blockManager.getBytesToReturnToPeerIncludingEndByte(nextByteToSendWithinRequest, lastByteWithinChunk) # hmmm. So the case is that if we don't have any bytes yet downloaded, we'll return as few as we now have, which means ever x sec's, we'll check again to see if there is more to write. ltodo optimize with the 'blank' endings
      send_data(nextToWrite)
      log "just successfully queued #{nextToWrite.length}B #{nextByteToSendWithinRequest } -> #{nextByteToSendWithinRequest + nextToWrite.length} out of #{endByte} in #{Time.now - start_send_time}s"
      nextByteToSendWithinRequest += nextToWrite.length
      if nextByteToSendWithinRequest == endByte + 1
        debug "done queueing all -- instructing it to close after writing"
        @sender_proc_wrapper.cancel
        @queued_all = true
        close_connection_after_writing
      end
    }
    #queued_proc = create_proc_that_runs_only_when_outbound_queue_gets_below(5, send_proc)  # run when it falls below X
    @sender_proc_wrapper = EventMachine::PeriodicTimer.new(how_often_check_queue_in_seconds, send_proc)
    send_proc.call # call it once early and fast!
  end
  
end # module

class P2PServer
  attr_accessor :serveAnyRequest
  attr_accessor :speedLimitPerConnectionBytesPerSecond
  attr_reader :port
  attr_reader :serverShouldStop
  attr_reader :aliveServerObjects

  def initialize bm, logger, predefinedPort = nil
    @blockManager = bm
    @logger = logger
    @predefinedPort = predefinedPort
    @serverShouldStop = false
    @speedLimitPerConnectionBytesPerSecond = nil
    @port = nil
    @log_prefix = "p2p server no port established yet log_prefix!"
  end
  include Logs 
  # ltodo it is conceivably possible to freeze all threads if an incoming something (recv?) freezes...not quite sure what happens but this one connection nukes it all.
  # wonder if that's the equivalent of an 'accept' that never does...muhaha.
  
  def serverCanStopNowNonBlocking
    if not @blockManager.done? # ltodo wherever says this change to assert
      error "ended server serving without being done?" # ndo fix tests to not violate this
    end
    debug "stopping server -- should close all clients on next_tick -- client queue length #{@aliveServerObjects.length}" 
    if @server_signature 
      EM::stop_server @server_signature # ltodo ask if this umm...disallows ALL none queued, nothing.
      @server_signature = nil
    else
      error "no server signatures for stop? ok if testing means that you wanted the server to 'stop early' for whatever reason..."
    end
    @serverShouldStop = true
    debug "killing length #{@aliveServerObjects.length}"
    @aliveServerObjects.each do |death, status|  # ltodo look into whether one can sneak in (use @serverShouldStop)
      debug "death to existing conn #{death}, status #{status}"
      death.close_connection
    end
  end

  def P2PServer.goodTCPPortGuessNumber
    return 1024 + rand(65535 - 1025) # looks random to me.
  end
  
  # vltodo cleaner way than 'find port'
  def P2PServer.getOpenTCPConn
    # will try this, then if it fails pick another :)
    port = P2PServer.goodTCPPortGuessNumber
    successfullPort = false
    attempts = 0
    while not successfullPort and attempts < 200
      begin
        server = TCPServer.new(port)
        successfullPort = true
        return port, server
      rescue Exception => exception
        successfullPort = false
        print "erred on port #{port} (which is ok) " + exception.to_s
        attempts += 1
        port = P2PServer.goodTCPPortGuessNumber
      end
    end
    
  end
  
  def P2PServer.findOpenTCPPort
    port, server = P2PServer.getOpenTCPConn
    server.close
    return port
  end
  
  def waitTillServerFiredUp() # for tests, I think -- used? ltodo
    sleep 0.1 while !@server_signature
  end
  
  def startServer
    @server_signature = nil
    assert(!@serverShouldStop, "server told to start already stopped!")
    if not @predefinedPort 
      @port = P2PServer.findOpenTCPPort
    else
      debug "using predefined port #{@predefinedPort}" # ltodo fire it up auto so we don't use it 'later'
      @port = @predefinedPort
    end
    @aliveServerObjects = {}
    count = 0
    attempts = 0
    begin
      @server_signature = EventMachine::start_server('0.0.0.0', @port, P2PServerConnection) { |clientConnection|
        @aliveServerObjects[clientConnection] = :an_active_client
        clientConnection.speedLimitPerConnectionBytesPerSecond = @speedLimitPerConnectionBytesPerSecond
        clientConnection.port = @port
        clientConnection.logger = @logger
        clientConnection.serverNumberedCount = count
        count += 1
        clientConnection.blockManager = @blockManager
        clientConnection.post_block self # allows it to delete itself from the aliveServerObjects after its untimely demise :) # ltodo make sure it never sends a byte, k?
      }
    rescue StandardError => e
      error 'ack retrying server port? -- got a bad one #{@port}'
      attempts += 1
      if attempts < 10
        @port = P2PServer.findOpenTCPPort
        retry
      else
        error "ACK NOT SERVING ANYTHING!!! BAAAAD presumabl out of ports for the server"
      end
    end
    @log_prefix = "p2p server :#{@port}"
    @blockManager.p2pServerPort = @port # ltodo do not tell it this! gross!
    debug "set block manager port to #{@port}"
  end
  
  # ltodo optimize against wget on my own servers, or me against wget using foreign apache, etc.
  # ltodo logger could use [ip:server_port]
end # class

# ltodo optimization get_last or get_2_last
# ltodo smaller dots/better colors or just better percentiles [ugh]

# ltodo graph openDHT scatter [3 of them], and compared with size scatter :)
