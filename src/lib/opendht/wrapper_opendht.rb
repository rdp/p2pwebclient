# this file no longer used, I believe
#require 'lib/opendht/opendht_rubyforge'
require 'pp'
require 'lib/logger.rb'
require 'lib/ruby_useful_here.rb'
require 'thread'
require 'constants.rb'
require 'lib/opendht/local_drive_dht'


# ltodo there are some XXXXXX 60 == 60 XX's -- huh? they seem to be some other thread (?)
# ltodo have each get/set/whatever say "took this long" just for my benefit :)
class Mutex
def waitTillOpen
 return self.synchronize {}
end
end

# ltodo do my own looping, report the times better, report 'endings' when interrupted by p2ptransferinterrupt
class ReceivedValidDataForGetAndWon < StandardError
end
class Peer
  def initialize(ip, port)
    @ip  = ip
    @port = port
  end
  attr_accessor :ip
  attr_accessor :port
  
  def to_s
    return "peer [#{@ip}:#{@port}]"
  end
  
end # class


class OpenDHTWrapper
  
  def newDHT
    @dht = @dhtClassToUse.new gw = nil, logger = @logger
  end
 # allow threads to not overlap efforts
  
  def initialize(urlIn, logger, dhtClassToUse = $dhtClassToUse)
    @inProcess = {} # these are reads
    @inProcessMutex = Mutex.new
    @cached = {} # their answers for reads
    assert logger.class.to_s == "Logger" # type checking :)
    # ltodo suggest type checking if you so desire like intiialize(urlIn :string, logger :Logger) yeah :)
#    @allPeersEverBlockNumberMapsToArray = {}
    @logger = logger
    @dhtClassToUse = dhtClassToUse
    @dht = newDHT()
    @ipAddressWithPortRE = /^peer:(\d+\.\d+\.\d+\.\d+):(\d+)$/
    @allThreadsStillRunning = {}    
    @allBlockSetsStillWaitingToSet = {}
    @logger.debug "using #{createKeyUrlBlocks('a',3).length} redundant keys per normal blockkey"
  end
  
  def doYouHaveAnyOutstandingRequestsOut?
    if @allThreadsStillRunning.length == 0
        return false
    else
        return true
    end
  end

  def waitForOpenThreadsToClose
    while @allThreadsStillRunning.length > 0
      begin
        thread = @allThreadsStillRunning.to_a[0][0]
        thread.join # should wait
        sleep 0.5 if @allThreadsStillRunning.length > 0# ltodo this does not be required to work--fix it!
      rescue => detail
        error "whoa interrupted! might be ok!" + detail.to_s + detail.class.to_s + detail.backtrace.join("\n")
      end
      debug "waiting for all opendhts to finish..."
    end
  end
  
  def OpenDHTWrapper.timeSelf(hashClass = $dhtClassToUse)
    @@logger = Logger.new("test/odhtwrapper_time_self.txt", 0)
    a = OpenDHTWrapper.new("fakeurl", @@logger, hashClass)
    localDht = hashClass.new
    name = "abcd" + rand(100).to_s
    print "a set takes >>\n"
    a.timedSet(localDht, name, "to this", "testing")
    print "a read takes\n"
    a.loggedRequest(name, "test req") # this is about the same speed as any read
    # ltodo k best on this ha ha 
  end
  
  def OpenDHTWrapper.testSelf(hashClass = $dhtClassToUse)
    log = Logger.new("test/opendhtwrapper", 0)
    a = OpenDHTWrapper.new("fakeurl",log, hashClass)
    localDht = hashClass.new
    test2 = true
    

    # vltodo break test to units 
    print "test set filesize non blocking"
    size = rand(100000)
    name = "fakey" + rand(10000).to_s
    thread = a.setFileSizeIntNonBlocking(size, name)
    thread.join
    sizeGot = a.getFileSizeIntOrNil(name)
    assertEqual(size, sizeGot)
    # try it again on purpose -- should have no assertion errors or anything :)
    
    thread = a.setFileSizeIntNonBlocking(size, name)
    thread.join
    assertEqual(size, a.getFileSizeIntOrNil(name))

    
    # ltodo test here 'only returns one!'
    
    urlName = "fakeurl" + rand(1000).to_s
    a.reportBlockDoneNonBlocking(1, urlName, "1.2.3.4", 3144)
    
    startTime = Time.new
    while Time.new - startTime < 60 &&  a.getPeers(1, urlName).length == 0
      print "check/wait"
    end
    
    peer = a.getPeers(1, urlName)[0]
    assert peer.ip = "1.2.3.4" and peer.port = 3144
    
    # test 2 opendhtwrapper set, get, rm
    if test2
      
      name = "a_test" + rand(100).to_s # sometimes fails!
      a.loggedSetNonBlocking(name, "bbd")
      startTime = Time.new
      while Time.new - startTime < 90 &&  a.loggedRequest(name, "test").length == 0
        print "still checking for opendht set #{name} == ", a.loggedRequest(name, "test output")
        sleep 5
      end
      
      assertEqual("bbd", a.loggedRequest(name, "test")[0], __LINE__)
      a.timedRM(localDht, name, "bbd", "")
      assertEqual([], a.loggedRequest(name, "test"), __LINE__)
    end
    
    
    a.setFileSizeIntBlocking(1001, "fakeurl") # ltodo wait or use the blocking one
    assertEqual(1001, a.getFileSizeIntOrNil("fakeurl"))
    
    url = 'fakeurl' + rand(1000000).to_s
    subject = OpenDHTWrapper.new(url, log, hashClass)
    myIP = '1.2.3' + rand(1000).to_s
    port = 1000
    subject.reportStartAccessingBlockOnCentralServer(url, 3, myIP, port)
    # let it post
    subject.waitForOpenThreadsToClose
    #pp "should be clear", subject #tlodo fix this wait
    sleep 3
    assertEqual subject.thoseAccessingOrigin(url, 3).length, 1
    subject.reportStartAccessingBlockOnCentralServer(url, 3, myIP + 'a', port)
    sleep 3
    assert subject.thoseAccessingOrigin(url, 3).length, 2
    subject.reportDoneAccessingBlockOnCentralServer(url, 3, myIP + 'a', port)
    sleep 3
    assertEqual subject.thoseAccessingOrigin(url, 3).length, 1
    subject.reportDoneAccessingBlockOnCentralServer(url, 3, myIP, port)
    sleep 3
    assert subject.thoseAccessingOrigin(url, 3).length, 0
    
    # now more than 10...eh...ltodo
    print "not testing more than 10 or 15 on the origin server block\n"
    1.upto(25) do |n|
      subject.reportStartAccessingBlockOnCentralServer(url + 'next', 3, myIP + "_#{n}_" + rand(1000000).to_s, port)
    end
    sleep 3 # tlodo fix
    subject.waitForOpenThreadsToClose
    accessing = subject.thoseAccessingOrigin(url + "next", 3)
    if accessing.length != 25
        pp "ERROR length should be 25--is #{accessing.length} look for missing", accessing.sort
        assertEqual accessing.length, 25 # ltodo with  rubyforge have the 'internal' gets done via dual gateway, not external
    end
 
    print "for your information:"
    OpenDHTWrapper.timeSelf(hashClass)
    
  end
  
  # ltodo  make sure I test everything here :)  
  
  def loggedRequest(toRequest, extraToOutput)
    beginTime = Time.new
    log "pre opendht request [#{toRequest}] #{extraToOutput}"
    answers = nil
    begin
      answers = @dht.getAsArrayOfValues(toRequest)
    rescue Exception => detail
      debug "got an interrupted opendht request [#{toRequest}] #{extraToOutput} Time elapsed: #{Time.new - beginTime}, raising it (#{detail.class}) #{detail}"
      log "post too slow opendht request [#{toRequest}] #{extraToOutput} [=> -1] Time elapsed: #{Time.new - beginTime}"
      raise
    end
    assert answers
    log "post opendht request [#{toRequest}] #{extraToOutput} [=> #{answers.length}] Time elapsed: #{Time.new - beginTime}"
    return answers
  end
  
  
  def removeNonBlocking(key, value, extraToOutput)
    newThread = Thread.new() { ||
      sleep 0
      @allThreadsStillRunning[Thread.current] = Thread.current # ltodo say = 1
      dhtRM =  @dht#newDHT # ltodo I wonder if it's the startup that takes all of this time...hmm...a pool, perhaps?
      timedRM(dhtRM, key, value, extraToOutput)
      @allThreadsStillRunning.delete(Thread.current)
    }
    newThread 
  end

  # LTODO if one of these fails it will upchuck...ugh...
  def timedRM(dhtToUse, key, value, extraToOutput)
    beginTime = Time.new
    log "pre opendht rm [remove #{key} => #{value}] #{extraToOutput}"
    dhtToUse.removeKeyValuePair(key, value)
    log "post opendht rm [remove #{key} => #{value}] #{extraToOutput} Time elapsed: #{Time.new - beginTime}"
  end
  
  
  def timedSet(dhtSend, key, value, extraToOutput)
    beginTime = Time.new
    log "pre opendht set [#{key} => #{value}] #{extraToOutput}"
    dhtSend.setNewKeyValuePair(key, value)
    log "post opendht set [#{key} => #{value}] #{extraToOutput} Time elapsed: #{Time.new - beginTime}"
  end
  
  def loggedSetNonBlocking(key, value, extraToOutput = "")
    Thread.new() { ||
      sleep 0
      @allThreadsStillRunning[Thread.current] = Thread.current
      dhtSend =  @dht#newDHT # ltodo this and others -- necessary, really?
      timedSet(dhtSend, key, value, extraToOutput)
      @allThreadsStillRunning.delete(Thread.current)
    }
  end
  
  def getIpAndPort(fromThisString)
    answers = @ipAddressWithPortRE.match(fromThisString)
    if answers != nil
      peerOut = Peer.new(answers[1], answers[2])
    else
      return nil
    end
  end
  class GiveUpODHT < StandardError
  end
  def getPeers(block, url)# ltodo no url needed
    assert block && url
    toRequest = createKeyUrlBlocks(url, block)[0]
    weOwnThisRequest = nil
    waitMutex = nil 
    begin
    @inProcessMutex.synchronize {

     if !@inProcess.has_key?(toRequest)
         waitMutex = Mutex.new
         waitMutex.lock
         @inProcess[toRequest] = waitMutex # they can all wait on it muhaha
         weOwnThisRequest = true
     else
         waitMutex = @inProcess[toRequest]
         weOwnThisThread = false
     end
   }
    if weOwnThisRequest # ltodo giveup shouldn't need special nesteds... how does timeout avoid this?
        winMutex = Mutex.new
        wonThreadRaceAlready = false
        peers = nil # ltodo note that...this only gets 9 and those 9 could be at 'different parts of the same list' for the different guys!
        # should be 10000
        stillHereMutex = Mutex.new # ltodo investigate ways to not have a still here mutex, nor a mutex for raising... "parent.raise_if_still_here_and_am_first" or something :)
       stillHereMutex.synchronize {
        threadRaceInjectsGiveUp(createKeyUrlBlocks(url, block), 1000000, false, ReceivedValidDataForGetAndWon, false) { |toRequest2| # ltodo tell ruby this should NOT change toRequest for the outside, I don't think! [change back to 2...]
                begin #the false means to not interrupt threads, once the first one finishes, so...they can add them to the global cache and return them later later :)
                        @allThreadsStillRunning[Thread.current] = Thread.current # ltodo prettier

                        debug "starting internal request for the subdivided key #{toRequest2}"
                        peers = loggedRequest(toRequest2, "block #{block}") # I wonder if there is a case of an openDHT that just returns bogus data...hmm...should I wait for th esecond in that case?
                        winMutex.synchronize {
                            if !wonThreadRaceAlready
                               if peers.length > 0
                                wonThreadRaceAlready = true
                                debug "#{toRequest2} won the peer gathering thread race -- I will return #{peers.length}, though the other may also be useful if it ever returns" # ltodo add these to some way to make sure there are non outstanding whe... (?)
                                assert peers
                                @cached[toRequest] = peers
                                if stillHereMutex.locked?
                                    raise(ReceivedValidDataForGetAndWon.new("#{toRequest2} won with success on getting peers of length #{peers.length}")) if peers.length > 0
                                else
                                    error "uh oh we legitimately won #{toRequest2} but...the system had abandoned us or something...stillHereMutex was not locked #{toRequest2} (possible if we moved on block-wise -- or if it's about to kill us...)"
                                end
                               else
                                   debug "we got zero peers, so are forlaying on declaring victory -- #{toRequest2}"
                               end
                            else
                                debug "#{toRequest2} lost the peer gathering thread race -- should add to the cache, in case the other is just plain broke, size #{peers.length}"
                            end
                        }
                rescue GiveUpODHT

                ensure
                        @allThreadsStillRunning.delete(Thread.current)
                end
        } # thread race
        debug "successfull post thread race for #{toRequest}"
       } # synchronize
# ltodo could try multiple gateways for set+rm [first back wins...]
        if  !@cached.has_key? toRequest
                debug "request for #{toRequest} apparently was unsuccessful in getting anything from any key  (or interrupted) -- storing []"
                @cached[toRequest] = []
        end
    else
        # we don't own it...hmm...
        waitMutex.synchronize {} # wait on it :)
        if !@cached.has_key?(toRequest)
            error  "no cache for this #{toRequest}? odd but I thought this could happen -- this better have been preceded by a p2ptransferinterrupt or a lingerisdone!" 
        else
                peers = @cached[toRequest]
                assert peers
        end
    end # ltodo a 'clean all entires for such and such a block' 
    ensure
      if weOwnThisRequest
        if !@cached.has_key?(toRequest)
          error "odd that I must presume this thread was interrupted before being able to actually received input on the query #{toRequest} somehow -- possibly a foreign injected interrupt -- if later ones complain it is because of this -- either that or all queries just failed!"
          @cached[toRequest] = []
        end
        @inProcessMutex.synchronize {
                assert toRequest
                waitMutex = @inProcess[toRequest]
                assert waitMutex, "it better be there!"
                waitMutex.unlock
                @inProcess.delete(toRequest) # this means that the very next peer will run another query -- that is what we want, appropriate!
        }
      end
    end
    appropriatePeers = []
    for peerString in peers do
      singlePeer = getIpAndPort(peerString)
      if singlePeer != nil
        appropriatePeers << singlePeer
      else
        error  "non peer from dht I think -- odd: " + peerString
      end
    end if peers
    return appropriatePeers
  end
  
  def debug a
    @logger.debug "odht wrapper: " + a
  end
 
  def error a
    @logger.error "odht wrapper: " + a
  end

  def log m
    @logger.log "odht wrapper: " + m
  end
  
  def getFileSizeIntOrNil(url)
    sizeKey = OpenDHTWrapper.dhtSizeKey(url)
    entries = loggedRequest(sizeKey, "file size")
    
    if entries == []
      return nil
    end
    
    if entries.length > 2 
      error("detected" + entries.length.to_s + "entries for file size on #{url}!")
    end # ltodo check make sure all the same.
    returnable = entries[0]
    returnable = returnable.to_i
    assert returnable > 0, "0 or negative sized files not allowed--we got #{entries[0]} from the DHT"
    return returnable
  end
  
  def setFileSizeIntNonBlocking(size, url)
    return Thread.new {
      sleep 0
      @allThreadsStillRunning[Thread.current] = Thread.current
      
      debug "TODO SET FILE SE OPENDHT"
      #setFileSizeIntBlocking(size, url)
      @allThreadsStillRunning.delete(Thread.current)
    }
    
  end
  
  def OpenDHTWrapper.dhtSizeKey(url)
    return "#{url}_size"
  end
  
  def setFileSizeIntBlocking(size, url)
    assert size.class.to_s == "Fixnum" # type checking :)
    sizeKey = OpenDHTWrapper.dhtSizeKey(url)
    oldFileSize = getFileSizeIntOrNil(url)
    
    if oldFileSize == size
      return
    else
      if oldFileSize != nil
        error  "discrepancy in file sizes? got #{oldFileSize}! not #{size}" # this failed with recreateBug like 3x in a row once
      end
    end
    
    size = size.to_s
    thread = loggedSetNonBlocking(sizeKey, size, "file size") # that is a generic function :)
    thread.join
    
  end
  
  def removeBlocksBlockingDoRemovesThenWaitThenRemainingRemoves(blockIndices, url, myIp, myPort)
    # fire them all off at once, then wait for each reply to return -- faster :)
    startThreadsThenJoin(blockIndices) { |blockNumber|
      removeBlockNonBlocking(blockNumber, url, myIp, myPort).join
    }
  end
  
  def removeBlockNonBlocking(blockNumber, url, myIp, myPort, ttl_unused = 1000000, hash_unused = "")
    if myPort.class != Fixnum
      print "ACK got port class of" + myPort.class.to_s + "\n"
    end
    assert myPort.class == Fixnum
    assert myPort != 0
    dhtKeys = createKeyUrlBlocks(url, blockNumber)
    dhtValue = createPeerListingString(myIp, myPort)
    Thread.new { 
        startThreadsThenJoin(dhtKeys) { |dhtKey | # we now do a lotta threads.
          if @allBlockSetsStillWaitingToSet.has_key? dhtKey
                debug "waiting for a set to finish, then doing rm #{dhtKey}"
                mutex =  @allBlockSetsStillWaitingToSet[dhtKey]
                mutex.waitTillOpen if mutex # wait on it. ltodo tell ruby "wait" would be nice...
                debug "done waiting for #{dhtKey} to end"
                assert !@allBlockSetsStillWaitingToSet.has_key?(dhtKey)
          end
          removeNonBlocking(dhtKey, dhtValue, "block #{blockNumber}").join
        }
    } # return that thread
  end
  
  def createKeyUrlBlocks(url, blockNumber)
    normalKey = "%s_block%d" % [url, blockNumber]
    return [normalKey, normalKey + "backupcopy"]
  end

  def createPeerListingString(iP, port)
    return "peer:%s:%d" % [iP, port]
  end
  
  # ltodo ttl make it work
  def reportBlockDoneNonBlocking(blockNumber, url, myIp, myPort, ttl = 1000000, endingHash = 'uncalculated_fake_hash')
    assertEqual myPort.class, Fixnum
    assert myPort != 0
    dhtKeys = createKeyUrlBlocks(url, blockNumber)
    dhtValue =  createPeerListingString(myIp, myPort)
    return Thread.new { startThreadsThenJoin(dhtKeys) { |dhtKey| 
        assert !@allBlockSetsStillWaitingToSet.has_key?(dhtKey)
        incomingMutex = Mutex.new
        begin
          incomingMutex.lock
          @allBlockSetsStillWaitingToSet[dhtKey] = incomingMutex
          loggedSetNonBlocking(dhtKey, dhtValue, "block #{blockNumber}").join 
          @allBlockSetsStillWaitingToSet.delete(dhtKey) # I think this will be unique  
        rescue Exception
          error "ahh!"
          raise
        ensure
          incomingMutex.unlock
        end
      } 
    } # simultaneous right now
  end
  
  def createAccessingOriginKey(url, block)
    return "%s_%d_origin" % [url, block]
  end
 # ltodo with 'real' runs i.e. true production I don't think that I should 'set' if it is coming in fast enough--if it's fast, let it be (?)
  def thoseAccessingOrigin(url, block)
    allCurrentlyListed = @dht.getAsArrayOfValues(createAccessingOriginKey(url, block), false)
    return allCurrentlyListed
  end
 
  def reportStartAccessingBlockOnCentralServer(url, blockNumber, ip, port) 
    key = createAccessingOriginKey(url, blockNumber)
    value = createPeerListingString(ip, port)
    thread = loggedSetNonBlocking(key, value, "block #{blockNumber}")
    return thread
  end
  
  # tlodo combine  
  def reportDoneAccessingBlockOnCentralServer(url, blockNumber, ip, port)
    key = createAccessingOriginKey(url, blockNumber)
    value = createPeerListingString(ip, port)
    removeNonBlocking(key, value, "block #{blockNumber}")
  end
  
  
  def getHashOfBlock(blockNumber)
    return "unfinished function retrieved fake hash"
  end
  
end

if runOrRunDebug? __FILE__
  OpenDHTWrapper.timeSelf
  OpenDHTWrapper.testSelf
end
