#!/usr/bin/env ruby

# ltodo in driver have an assertion that 'other threads are dead!'
# ltodo when a peer dies early it must clean up DHT blocks, and also its own blocks. Or should. and sockets.
# ltodo on err dump the file...
require './constants'
require 'cs_and_p2p_client.rb'
require 'optparse'

class RaiseMeError < StandardError # ltodo rename
end

# ltodo hup no longer used
# ltodo kills should work kill, graceful_end similarly
class Array # ltodo would this be useful to other 'cull' ing locations?
  def setCullTime toThis
    @lastCullTime = toThis
  end
  
  def cullIfShould(secondsAllowed = 2)
    assert defined?(@lastCullTime)
    if Time.new - @lastCullTime > secondsAllowed
      @lastCullTime = Time.new
      newPossiblyLesserArray = self.cullDeadThreadsInArray
      newPossiblyLesserArray.setCullTime Time.new
      return newPossiblyLesserArray
    else
      return self
    end
  end
end


class ListenerEM < EM::Connection
  @@createClientMutex = Mutex.new
  def post_block logger
    @logger = logger
    self
  end
  
  def receive_data incomingText
    @logger.debug "got incoming text #{incomingText.inspect}"
    # tltodo when send req's, etc. do flush
    incomingText.strip!
    if incomingText == "version"
      @logger.debug "got version, answering #{$version} [only--no longer the ruby version too]"
      send_data("#{$version}\n")
      close_connection_after_writing
      return
    end
    
    if incomingText == "ruby_version"
      answer = RUBY_DESCRIPTION + Config::CONFIG['CFLAGS']
      @logger.debug "got ruby_version, answering #{answer}"
      send_data answer
      close_connection_after_writing
      return
    end
    
    if incomingText == "killEverything" # shuts down hard shutdown, permanent
      @logger.debug "doing kill everything! ahh!"
      system("killall /bin/bash")
      @logger.debug "now killing ruby! Oh the sacrifice!"
      @logger.close
      system("killall ruby")# wow
    end

    if incomingText == "delete_all_logs"
      require 'fileutils'
      FileUtils.rm_rf "../logs"
      @logger.debug("deleted all logs!")
      return;
    end
    
    if incomingText == "svnup" or incomingText == "svnup_restart"
      @logger.debug "doing svn up"
      system("git pull")
      send_data("old version is #{$version}, done updating, will restart if you sent svnup_restart...")
    end
    
    if incomingText == "restart" or incomingText == "svnup_restart"
      @done = true
      @logger.debug "got restart--raising!\n\n\n\n\n\n\n"
      send_data("restarting")
      raise RaiseMeError.new("got restart or svnup_restart, so raising...")# ltodo do we close it?
    end
    
    if incomingText == "doneWithRun?"
      clientsOutstanding = BlockManager.clientsStillRunning
      if clientsOutstanding.empty?
        answer = "yes"
      else
        clients_still_running = BlockManager.clientsStillRunningAndDownloading
        answer = "no -- lacking #{clientsOutstanding.length} clients overall, #{clients_still_running.length} still downloading)"
      end
      @logger.log "got request for am done -- answering #{answer}"
      send_data(answer)
    elsif incomingText == "breakpoint"
      breakpoint
    else # a request to go for it :) ltodo a header :)
      # ltodo T/F graphs side by side [two setting...hmm...]
      incomingSettings = incomingText.split(",") # hope they match, and that , is ok :) [should be]
      fullUrl=blockSize=fileSize=spaceBetweenNew=totalSecondsToContinueGeneratingNewClients=dTToWaitAtBeginning=dRIfBelowThisCutItBps=dWindowSeconds=linger=runName=serverBpS=peer_tokens=peer_name=startTime=p2pIgnoreCS=doNotInterruptOriginThreadButYesP2P=pRETEND_CLIENT_SERVER_ONLY=useOriginRevertOptimization=getAllAtBeginning=use_many_peers_no_single_thread = nil
      @@createClientMutex.synchronize {
        fullUrl,blockSize,fileSize,spaceBetweenNew,totalSecondsToContinueGeneratingNewClients,dTToWaitAtBeginning,dRIfBelowThisCutItBps,dWindowSeconds,linger,runName,serverBpS,peer_tokens,peer_name,startTime,p2pIgnoreCS,doNotInterruptOriginThreadButYesP2P, pRETEND_CLIENT_SERVER_ONLY, useOriginRevertOptimization, useOriginBackOffOrNumberConcurrent, getAllAtBeginning, use_many_peers_no_single_thread = parseArgsToRubyObjectsArray(incomingSettings)
        
        if use_many_peers_no_single_thread == nil
          @logger.error "ack mis set incoming specs for this![#{use_many_peers_no_single_thread}] from incoming #{incomingText} => #{parseArgsToRubyObjectsArray(incomingSettings).length} (#{parseArgsToRubyObjectsArray(incomingSettings)})"  # should be ok
        else
          @logger.debug "this incoming text works for spawning a new peer:" + incomingText
         # reloading it necessary since we [sigh] use globals, and in a shared environment, allowing them to ever be set to nil was a BAD idea
          fullUrl,blockSize,fileSize,spaceBetweenNew,totalSecondsToContinueGeneratingNewClients,dTToWaitAtBeginning,dRIfBelowThisCutItBps,dWindowSeconds,linger,runName,serverBpS,peer_tokens,peer_name,startTime,$p2pSkipCS,$doNotInterruptOriginThreadButYesP2P, $PRETEND_CLIENT_SERVER_ONLY, $useOriginRevertOptimization, $useOriginBackOffOrNumberConcurrent, $getAllAtBeginning, $USE_MANY_PEERS_NO_SINGLE_THREAD =  parseArgsToRubyObjectsArray(incomingSettings)
          assert peer_tokens != nil and $p2pSkipCS != nil and $doNotInterruptOriginThreadButYesP2P != nil and $PRETEND_CLIENT_SERVER_ONLY != nil and $useOriginRevertOptimization != nil and $getAllAtBeginning != nil and $USE_MANY_PEERS_NO_SINGLE_THREAD != nil
        end
      }
      if startTime == nil or fullUrl == nil
        @logger.error "listener unable to parse " + incomingText
      else
        if startTime.class != Float
          print "startTime is #{startTime}, converting..."
          startTime = startTime.to_f
        end
        @logger.debug "got request for [driver's] client number #{peer_name}"
        # ltodo better time, too.  Save it, maybe, right here :)
        if $USE_MANY_PEERS_NO_SINGLE_THREAD
          assert false, 'unused'
        else # ltodo test that this still works :)
          fireOneLocalEM(fullUrl, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, spaceBetweenNew, linger, startTime, peer_name, totalSecondsToContinueGeneratingNewClients, runName, serverBpS, peer_tokens)    # note does not include any globals...hmm...
        end
        send_data("fired it successfully!\n total is now #{BlockManager.clientsStillRunning.length}")
      end
    end
    # close it, but allowing for that debug timeout...yucky one :)
    close_connection_after_writing
  end
  # doctest_require: Thread .new { EventMachine.fireSelfUp }; nil 
  # doctest: shares_logger it should 
  # >> logger = Logger.new('test/fake_name' + rand(1000000).to_s)
  # >> logger1 = Logger.new('test/fake_name' + rand(1000000).to_s)
  # >> BlockManager.startCSWithP2PEM 'http://wilkboardonline.com/roger/p2p/test_files/25K.file', 2,2,3,100_000,1,20,0, 'no44_name', 1, 'no44_name2', 3, 3, logger1, :use_this_shared_logger => logger
  # >> BlockManager.startCSWithP2PEM 'http://wilkboardonline.com/roger/p2p/25K.file', 2,2,3,100_000,1,20,0, 'no55_name', 1, 'no55_name2', 3, 3, logger1, :use_this_shared_logger => logger
  # >> logger.read_whole_file.include?('44')
  # => true
  # >> logger.read_whole_file.include?('55')
  # => true
  # doctest: downloads multiple files
  # >> Thread.new { EventMachine.fireSelfUp }
  # >> logy = Logger.new('fake_name3')
  # >> listener_instance = ListenerEM.new('unknown').post_block(logy)
  # >> instance = listener_instance.fireOneLocalEM('http://wilkboardonline.com/roger/p2p/25K.file;http://wilkboardonline.com/roger/p2p/25K.file',2,2,3,100_000,1,20,0, 'downloads_multiple', 1, 'unknown', 3, 3)
  # >> sleep 3
  # >> instance.logger.read_whole_file.include?('ALL TOTALLY DONE')
  # => true
  # it should also say totally done even if there's only one:
  # >> instance = listener_instance.fireOneLocalEM('http://wilkboardonline.com/roger/p2p/25K.file',2,2,3,100_000,1,20,0, 'downloads_multiple', 1, 'unknown', 3, 3)
  # >> sleep 2
  # >> instance.logger.read_whole_file.include?('ALL TOTALLY DONE')  
  #
  # doctest: if you have a first that lingers "0" and another starting after, both should be able to write to the log
  # >> Thread .new { EventMachine.fireSelfUp };
  # >> logy = Logger.new('fake_name3')
  # >> listener_instance = ListenerEM.new('unknown').post_block(logy)
  # >> instance = listener_instance.fireOneLocalEM('http://wilkboardonline.com/roger/p2p/25K.file;http://wilkboardonline.com/roger/p2p/25K.file',2,2,3,100_000,1,:linger => 0, :startTime => 0, :peer_name => 'downloads_multiple', :totalSecondsToContinueGeneratingNewClients => 1, :runName => 'unknown' + rand(1000000).to_s, :serverBpS => 3, :peer_tokens => 3)
  # >> sleep 0.1 while !instance.opendht_done_and_logger_closed # let the first one finish
  # >> sleep 15 # todo change this to a 'wait till all are done'
  # >> instance.logger.read_whole_file.split("DONE WITH WHOLE FILE").length
  # => 3
  # it might keep writing to the file here??
  # >> [nil, 0].include? instance.logger.messages_received_after_close
  # => true

  def fireOneLocalEM(fullUrl, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, spaceBetweenNew, linger, startTime, peer_name, totalSecondsToContinueGeneratingNewClients, runName, serverBpS, peer_tokens)
     @logger.log "Listener starting peer #{peer_name} at #{startTime} url #{fullUrl}!"
    
      # the multi multi! yes!
      first_url, rest = fullUrl.split(';')
      @logger.debug("doing urls: #{first_url} #{rest.inspect}")
      rest = Array(rest)
      first_runner = nil

      amount_still_running = rest.length + 1 # don't want to disallow the first client from finishing its opendhts, etc [we'd close the logger early on it]
      close_logger_maybe_proc = proc {
        amount_still_running -= 1
        first_runner.logger.log "congratulations--post cleanup called--you're totally done" if amount_still_running == 0
        first_runner.logger.close if amount_still_running == 0
      }

      started_first_Time = Time.now
      fire_rest = proc {
        total_left_downloading = rest.length
        first_runner.logger.log("ALL TOTALLY DONE") if rest == [] # no rest--we're done
        rest.each { |second_url|
          new_start_time = startTime + (Time.now - started_first_Time)
            BlockManager.startCSWithP2PEM(second_url, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, spaceBetweenNew, linger, new_start_time, peer_name.to_s + ":url:#{second_url.sanitize}", totalSecondsToContinueGeneratingNewClients, runName, serverBpS, peer_tokens, @logger, :use_this_shared_logger => first_runner.logger, :do_not_shutdown_logger => true, :completion_proc => proc { total_left_downloading -= 1; first_runner.logger.log("ALL TOTALLY DONE") if total_left_downloading == 0}, :termination_proc => close_logger_maybe_proc)
        }
      }
      
      # start the first guy
      opts = {:completion_proc => fire_rest} # always write 'ALL TOTALLY DONE'
      opts[:do_not_shutdown_logger] = true # ltodo not use I guess
      opts[:termination_proc] = close_logger_maybe_proc
      first_runner = BlockManager.startCSWithP2PEM(first_url, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, blockSize, spaceBetweenNew, linger, startTime, peer_name, totalSecondsToContinueGeneratingNewClients, runName, serverBpS, peer_tokens, @logger, opts)
      
  end  
  named_args :fireOneLocalEM
  
end

class Listener # ltodo when a peer dies it should cleanup better
  def initialize port
    host_ip = Socket.get_host_ip 
    # a blank host_ip here is ok...I guess...no reason why having a listener with unreliable log location is a problem raise 'unable to determine host ip--bad!' if host_ip.blank?
    subDir = "../logs/#{host_ip}"
    Dir.mkPath subDir if not File.directory? subDir
    @logger = Logger.new("#{subDir}/all_listener_output_only.txt", 1000000, "listener" + rand(1000).to_s)
    @port = port
    @logger.log "listening on port #{port}"
  end
  def debug message
    @logger.debug "listener:" << message
  end
  
  attr_reader :done
  def start_listening
    @listenerServerSig = EM::start_server('0.0.0.0', @port, ListenerEM) { |conn|
      conn.post_block @logger
    }
    
  end
  # ltodo take out thread.new's within this
  def listenForeverBlocking
    unless EventMachine::reactor_running?
      debug "running SINGLE THREAD!"
      EM::run {
        EM::PeriodicTimer.new(300, proc { debug 'listener 300s ping'}) # this is actually never cancelled (yet)
        listenForeverLoopingOnErrorNonBlocking
      }
      debug "listener EM done--EM.run ended"
    else
      debug "aww still multiple threaded [but still EM]...!"
      listenForeverLoopingOnErrorNonBlocking
      sleep
    end
  end
  
  def listenForeverLoopingOnErrorNonBlocking
    debug "starting listener on #{@port}"
    @listenerServerSig = EM::start_server('0.0.0.0', @port, ListenerEM) { |conn|
      conn.post_block @logger
      debug "listener got incoming request start on #{@port}"
    }
    return @listenerServerSig
  end
  
  def stopBlocking # ltodo rename
    EM::stop_server @listenerServerSig # rest should clear up immediately, really, so we're ok
  end
  
  def Listener.listen port = $allListenersPort
    listener = Listener.new port
    listener.listenForeverLoopingOnErrorNonBlocking
    return listener
  end
  
  def Listener.getOutputFileNameAfterIP blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, linger, runName, serverBpS
    return runName + "_dClient#{spaceBetweenNew}_dTotal#{totalSecondsToContinueGeneratingNewClients}_dw#{dWindowSeconds}_blockSize#{blockSize}_linger#{linger}_dr#{dRIfBelowThisCutItBps}_dt#{dTToWaitAtBeginning}_serverBpS#{serverBpS}/" # ltodo add numclients (?)
  end
  require 'fileutils'
  def Listener.getOutputDirectoryName blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, linger, runName, serverBpS
    assert serverBpS
    host_ip = Socket.get_host_ip
    raise 'unable to determine localhost ip addy' if host_ip.blank?
    subDir = "../logs/" + host_ip  + "/" # where those logs will go :)
    FileUtils.mkpath(subDir) unless File.directory? subDir # this is where we force its creation ltodo move somewhere (global) :)
    directoryName = subDir + Listener.getOutputFileNameAfterIP(blockSize, spaceBetweenNew, totalSecondsToContinueGeneratingNewClients, dTToWaitAtBeginning, dRIfBelowThisCutItBps, dWindowSeconds, linger, runName, serverBpS)
    return directoryName
  end
  
  
end

if $0 == __FILE__ or debugMe('listener') # ltodo take out old's
  listenPort = $allListenersPort
  use_rev = false 
  OptionParser.new do |opts|
    opts.banner = "Usage: #{__FILE__}  [options]"

    opts.on('--use_rev', 'use Rev instead of EM') do;  print "using REV\n"; use_rev = true; end

    opts.on('--port=NUMBER', "specify a port for this listener default is #{listenPort}") do |port|
      listenPort = port.to_i
      raise 'bad port arg' if listenPort == 0
    end
  end.parse!

  print "Listener starting up on port #{listenPort}\n...sleeping forever probably ltodo catch keyboard, close..."
  if use_rev
    #require 'lib/rev_here'
    require 'lib/revem_here'
    #require '/Users/rogerpack/dev/rev_committable/trunk/lib/rev'
    #require './instance_exec'
  end
  # run epoll...only here since if you run it with driver, in a different thread, it will cause some priority issues [read: EM multithread == bad idea]
  unless Socket.gethostname =~ /roger/i# todor change user after!, start as sudo^M
     EventMachine::start_epoll_many_descriptors 'byu_p2pweb'
     EM::grab_lotsa_descriptors
  else
     pp 'not grabbing! kqueue is bad!'
  end

  listener = Listener.new listenPort
  listener.listenForeverBlocking
end
