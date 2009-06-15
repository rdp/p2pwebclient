class HangingDHT
  def initialize gw = nil, logger = nil
    
  end
  def getAsArrayOfValues key, fakeBool = false
    sleep
  end
  def removeKeyValuePair key, value
    sleep
  end
 def []=(key, value) sleep end
  
end

class LocalDriveDHT
 $localDriveMinWaitTime = 0.5 # make it changeable by tests...
 @@waitTimeBeyondThat = 0.01
 Dir.mkPath "/tmp/dht" # ltodo is this where I should? centralized? 
 def initialize gw = nil, logger = Logger.new("test/local_drive_dht_logger.txt", 500000)
   @logger = logger
 end
# ltodo have it store the file as key[key]_value[value]...save the errors during testing :)
# ltodo rename everything ".dht"
 attr_accessor :waitTime
 def sleepTime
      sleep $localDriveMinWaitTime + rand()*@@waitTimeBeyondThat
 end

 # ltodo better for sanitize  -- replace with their ascii number equivalent or something, post :)

 def LocalDriveDHT.testSelf
  OpenDHTWrapper.testSelf(LocalDriveDHT)
 end
 
 def getAsArrayOfValues(key, fakeBool = false)
  sleepTime
  key = key.sanitize
 
  all = []
  for filename in Dir.glob("/tmp/dht/#{key}_*")
    begin
      a = File.new(filename, "r")
      all << a.read
      a.close
    rescue => detail # TODO catch real errors
      begin
        a.close if a and !a.closed?
      rescue Errno::EBADF
        @logger.error "windows is at it again, confusing my descriptors or something"
      end
      @logger.debug "ACk! seems that a #{key}_* file disappeared before we could read it! #{detail.class} #{detail}" # ltodo put in filename...double check
      raise if detail.class == P2PTransferInterrupt or detail.class == GiveUp

    end
  end
  all
 end

# ltodo check if I should allow duplicates, which I don't
 def removeKeyValuePair(key, value)
  sleepTime
  key = key.sanitize
  for filename in Dir.glob("/tmp/dht/#{key}_*")
  # small race condition --right now we read through several files -- if one has 'disappeared' just then, I suppose
    begin
      a = File.new(filename, "r")
    rescue => detail # ltodo rescue better! real!
# ltodo print "ack #{filename} was spontaneously deleted? we tried to read random key and it was gone (ok...) "# verbose ltodo  + detail
      a.close if a and !a.closed?
      if detail.class == P2PTransferInterrupt then raise end
      next
    end
    max = 100
    count = 0
    if a.read == value
      a.close
      successfulDelete = false
      while not successfulDelete
        begin
          File.delete(filename)
          successfulDelete = true
        rescue => detail
          if detail.class == P2PTransferInterrupt then raise end
          successfulDelete = false
          if count > max # ltodo look into the permission denied bug here
            @logger.debug "SEEDO ack delete failed after #{count} attempts! Not deleting DHT key!" + detail.to_s
            successfulDelete = true
          else
            count += 1
            sleep 0 # could be reached here in earnest!
          end
        end
       end
#      print "successful delete" # ltodo double check for duplicates, maybe just use the filename for info (nah)
    else
      a.close
    end
  end  
  
 end
 
 def []=(key, value)
    sleepTime
    key = key.sanitize
    begin
        a = File.new("/tmp/dht/#{key}_#{rand(1000000000)}", "wb") 
        a.write(value)
        a.close
    rescue => detail
      a.close if a and !a.closed?
      print "ack unable to write to local file dht!"
    end
 end
 alias :setNewKeyValuePair :[]=
end
