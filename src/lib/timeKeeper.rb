
class HistElement
  
  def create(time, size)
    @time = time
    @size = size
  end
  
  def to_s
    return "[@%fs %dB]" % [@time, @size]
  end
  attr_accessor :time, :size
end

class TimeKeeper
  def initialize(logger)
    @logger = logger
    @receivedHistoryArray = []
    @creationTime = Time.new
  end
  
  def TimeKeeper.testSelf
    a = TimeKeeper.new Logger.new("test/time_kee-er_testself.log", 7777)
    assert a.timeBeforeCouldFallBelow(100, 5) == 0
    a.addToHistoryWindow(10)
    sleep 0.1
    a.addToHistoryWindow(20)
    bps = a.calculateSpeedBytesPerSecond(1)
    print "bps is ", bps
    assertEqual bps, 30 
    bps = a.calculateSpeedBytesPerSecond(5)
    assertEqual bps, 30/5.0
    
  end
  # use case two downloading simultaneously should be faster than straight up (for example) :)
  def addToHistoryWindow(length) # ltodo testSelf this
    nextHistElement = HistElement.new
    nextHistElement.create(timeSinceInception, length)
    @receivedHistoryArray << nextHistElement
  end
  def timeSinceInception
   (Time.new - @creationTime).to_f
 end
  def timeBeforeCouldFallBelow thisSpeed, thisWindow
    # that would bewhen the sum, working backwards, of recorded events, is less than that. So start at present
    sum = 0
    @receivedHistoryArray.reverse_each { |entry|
      sum += entry.size
      if sum >= thisSpeed            
        timeNow = (Time.new - @creationTime).to_f
        thingsGoOutOfScope =  timeNow - thisWindow
        secondsThisOneHasLeft = entry.time - thingsGoOutOfScope
        return secondsThisOneHasLeft + 0.01
      end
    }
    return 0 # guess we don't even have enough to meet it, now!
    
  end
  
  def calculateSpeedBytesPerSecond(dWindow)
    timeNow= (Time.new - @creationTime).to_f
    #  debug "size of all received segment array is %d" % @receivedHistoryArray.length 
    # for each entry in the array within 5 or what not...use it!
    # entries are time, length
    sumBytes = 0
    # nuke off the first entries
    cutOffTime = timeNow - dWindow
    newArray = []
    for entry in @receivedHistoryArray
      if entry.time > cutOffTime
        newArray << entry
        sumBytes += entry.size
      else
        # pp "dropping", entry, "cut off time", cutOffTime
      end 
    end
    bps = sumBytes/dWindow
    #verbose    @logger.debug "returning %d/%f window => %f Bps\n" % [sumBytes, dWindow, bps]
    @receivedHistoryArray = newArray
    return bps
  end # func
  
  def floatTimeWhenNextChunkExpires(dWindow)
    nextChunk = @receivedHistoryArray[0]
    # so say nowTime is 1000, next chunk was given at 970 with a window of 50 -- that would be 970 - (1000 - 50)
    nowTime = (Time.new - @creationTime).to_f
    return nextChunk.time - (nowTime - dWindow)
  end
  
end
