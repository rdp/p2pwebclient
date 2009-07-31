require File.dirname(__FILE__) + '/constants'
require_rel 'individual_graph'
require 'tempfile'

class LineWithPointsFile
  
  def initialize(filename)
    @filename = filename 
    @allLinePoints = nil
  end
  
  def LineWithPointsFile.readSingleToArray(filename)
    return readSingle(filename)
  end
  
  def LineWithPointsFile.readSingle(filename)
    return LineWithPointsFile.new(filename).read[0][1]
  end
  
  def LineWithPointsFile.readSingleToHash(filename)
    return readSingle(filename).dupleArrayToSummedHash
  end
  
  def LineWithPointsFile.writeAndReadSingleToHash(filename, lineName, array)
    return writeAndReadSingle(filename, lineName, array)
  end
  
  def LineWithPointsFile.writeAndReadSingle(filename, lineName, array)
    rawOut = LineWithPointsFile.new(filename)
    rawOut.write([[lineName, array]])
    return LineWithPointsFile.new(filename).read[0][1]
  end
  
  def LineWithPointsFile.readToHashInts(filename)
    parsedIn = LineWithPointsFile.new(filename).readAsIntHashes # yeah :)
    return parsedIn
    
  end
  
  def LineWithPointsFile.readToArrayHashes(filename)
    return LineWithPointsFile.new(filename).readAsHashes
    
  end
  
  def LineWithPointsFile.readToArrayInts(filename)
    rawOut = LineWithPointsFile.new(filename)
    parsedIn = LineWithPointsFile.new(filename).readAsIntBuckets # ltodo rename intArrays
    return parsedIn
    
  end
  
  def LineWithPointsFile.readSingleToHashInt(filename)
    return LineWithPointsFile.readToHashInts(filename)[0][1]
  end
  
  def LineWithPointsFile.readSingleToArrayInt(filename)
    return LineWithPointsFile.readToArrayInts(filename)[0][1]
  end
  
  
  def LineWithPointsFile.writeAndReadSingleToHashInt(filename, lineName, array)
    rawOut = LineWithPointsFile.new(filename)
    rawOut.write([[lineName, array]])
    return LineWithPointsFile.readSingleToHashInt(filename)
  end
  
  def LineWithPointsFile.writeAndReadToArrayInt(filename, lineName, array)
    rawOut = LineWithPointsFile.new(filename)
    rawOut.write([[lineName, array]])
    parsedIn = LineWithPointsFile.new(filename).readAsIntBuckets[0][1]

    return parsedIn
    
  end
  
  
  def write(thesePoints = [["line1", [[0,1] [1,1]]], ["scatter2", [[0,0], [0,1]]]])
    f = File.new(@filename, "w")
    for name, points in thesePoints
      f.write("\"#{name}\"\n")
      for point in points
        assert point.length == 2
        f.write("[#{point[0]},#{point[1]}]\n")
      end
    end
    f.close
  end
  
  def read
    titleRegEx = /"(.*)"/
    pointRegEx = /\[(.*),(.*)\]/
    f = File.new(@filename, "r")
    @allLinePoints = []
    currentLinePointDuple = nil
    f.each_line { |line|
      match = titleRegEx.match(line)    
      if match
        @allLinePoints << [match[1], []]
      else
        match = pointRegEx.match(line)    
        if match
          @allLinePoints.last[1] << [match[1].to_f, match[2].to_f] # insert that on the last one :)
        else
          print "ACKKK!!!!!!!!"
        end
      end
    }
    f.close
    return  @allLinePoints
  end
  
  def readAsHashes
    read # ltodo have read double check it doesn't get called twice :)
    outLineHashes = []
    for name, line in @allLinePoints
      outLineHashes << [name, line.dupleArrayToSummedHash]
    end
  end
  
  def readAsIntHashes
    if @allLinePoints.nil?
      read
    end
    allIntHashes = []
    for lineName, points in @allLinePoints
      allIntHashes << [lineName, points.toSummedByIntegerHash]
    end
    return allIntHashes
  end
  
  def readAsIntBuckets
    if @allLinePoints.nil?
      read
    end
    allIntBuckets = []
    for lineName, points in @allLinePoints
      allIntBuckets << [lineName, points.collapsePointsToIntegers]
    end
    return allIntBuckets
  end
  
  def LineWithPointsFile.testSelf
    subject = LineWithPointsFile.new("test/test.line")
    allTests = [ [["line1", [[0,1], [1,1]]], ["scatter2", [[0,0], [0,1]]]],
    [["line1 2 3", [[0.0,1.9], [100,19]]], ["scat3ter2", [[0.09,90], [0.1,1]]]]]
    for testPoints in allTests
      subject.write(testPoints)
      subject2 = LineWithPointsFile.new("test/test.line")
      assertEqual testPoints, subject2.read
    end
    collapseMe = [["line1", [[0.5,1.0], [1.9,1.0], [1.8, 2.0]]]]
    subject.write(collapseMe)
    assertEqual subject.read, collapseMe
    assertEqual subject.readAsIntBuckets, [["line1", [[0,1.0], [1,3.0]]]]
  end
end


class OpenDHTDoSomething
  attr_accessor :type
  attr_accessor :start
  attr_accessor :endy
end

class ClientLogContainerWithStats
  
  def initialize(filename)
    @filename = filename
    @end = nil
    @start_time = Time.now
    print "Parsing #{filename} \n"
    @internalSingleGrapher = IndividualGraph.new(filename, self) if $doIndividuals
    #@saveThese = {'$' => 'opendht sum gets'}
    #@parsedElementsOfType = {'$' => []}
    @subject = SingleLogParser.new(@filename)
    @openDHTs = []
    @allReceivedP2P = []
    @allReceivedHost = []
    @allServedP2P = []
    @endMethod = 'http_straight' # ltodo rename 'switchtoP2preason'
    # ltodo a 'test case' for parsing yeesh :)
    @logFinished = false
    @openDHTsInProcess = {}
    parse
    unless @openDHTsInProcess.empty?
        print "Ack -- openDHTsInProcess wasn't empty like some were still in flight or something!\n"
    end
    @openDHTsInProcess = nil
    # need lastLine, still....@subject = nil
    fileize_yourself
    print "done -- took #{Time.now - @start_time}s\n" 
  end
=begin
doctest: fileize_yourself should write out temp files and allow them to be read back 
>> a = ClientLogContainerWithStats.allocate
>> a.instance_variable_set :@allReceivedP2P, ['abc', 'def']
>> a.fileize_yourself
>> a.allReceivedP2P
=> ["abc", "def"]
=end
  @@temp_prefix = rand(1000).to_s + 'yup'
  def fileize_yourself
        for item in [:@openDHTs, :@allReceivedP2P, :@allReceivedHost, :@allServedP2P] do
           variable_instance = self.instance_variable_get(item)
           a = Tempfile.new @@temp_prefix + rand(1000000).to_s
           a.write Marshal.dump(variable_instance)
           a.close
           self.instance_variable_set(item, a)
        end

  end

  def read_from_marshalled_data name
     # read in the data from a temp file, unmarshal it...
     file = self.instance_variable_get(name)
     file.open # reopen it
     contents_as_ruby = Marshal.load file.read
     file.close
     contents_as_ruby
 end

  def allReceivedP2P
    read_from_marshalled_data :@allReceivedP2P
  end

  def allReceivedHost
    read_from_marshalled_data :@allReceivedHost
  end

  def allServedP2P
   read_from_marshalled_data :@allServedP2P
  end

  def getAllOpenDHTItems
    read_from_marshalled_data :@openDHTs
  end

  attr_reader :parsedElementsOfType
  attr_reader :subject
  def ClientLogContainerWithStats.testSelf
    a = File.new("fakefile", "w")
    a.close
    a = ClientLogContainerWithStats.new('fakefile') # ltodo delete
    a.processToken(['fakeblocknumber', -1, '$', '0.34'])
    assert a.parsedElementsOfType['$'].length == 1
  end
  
  def sumServed #ltodo test this, with some pre known hard coded value
    sumServed = 0
    for servedTuple in @allServedP2P
      sumServed += servedTuple[1]
    end
    return sumServed
  end
  
  attr_reader :filename
  attr_reader :end, :start, :logFinished, :endMethod
  
  def sumReceivedPeers
    return self.allReceivedP2P.sumValues
  end
  
  def sumServed
    return self.allServedP2P.sumValues
  end
  
  def percentFromPeers
    peerSum = sumReceivedPeers
    hostSum = sumReceivedHost
    return peerSum.to_f / (peerSum + hostSum)
  end
  
  def sumReceivedHost()
    return self.allReceivedHost.sumValues
  end
  
  def createIndividual dirNameOut
    clientHost = @filename.split('/')[2]
    outputFile = dirNameOut + '/' +  "%.02f" % (totalDownloadTime || '-1') + "Total_" + File.basename(filename) + "_IndividualGraph_#{clientHost}.txt"
    @internalSingleGrapher.generate @subject, outputFile # ltodo ugly
  end
  
  
  def parse
    # ltodo verify I use this for individual graph  [or maybe clientlog.doindividual but I might already be doing that]:)
    while token = @subject.getNextGraphableToken
      processToken(token)
    end # each token
    assert @endMethod, "no fail method reported is impossible!!!"

  end
  
  def processToken token
    if token != :nonToken
      @internalSingleGrapher.andand.addToken token
      # add it to the individual grapher, just in case that it useful
      blockNumber, secondFloat, symbol, description, extra, extra2 = token
      if symbol == 'F'
        @endMethod = 'dR'
      end
      
      if symbol == 'W'
        @endMethod = 'dT'
      end
      
      if extra
        # dht most likely...
        if symbol.in? ['R', 'G', 'S'] # a START openDHT
          inObject = OpenDHTDoSomething.new
          inObject.type = symbol
          inObject.start = secondFloat
          assert !extra.blank?
          if @openDHTsInProcess.has_key? extra
            print "W!" # a restart?
          else
            @openDHTsInProcess[extra] = inObject
          end
        elsif symbol.in? ['a','r','s','b','g','c'] # done
          assert !extra2.blank?
          if !@openDHTsInProcess.has_key?(extra2) then 
            print "BADK! #{extra2} not found in #{@openDHTsInProcess.inspect}\n"
          else
            openDHTThatJustFinished = @openDHTsInProcess[extra2]
            openDHTThatJustFinished.endy = secondFloat
            @openDHTs << openDHTThatJustFinished
            @openDHTsInProcess.delete(extra2)
          end
        else
          # ltodo            print "non dht extra -- like a byte metric" + token.to_s
        end
      end
      
      #for char, description in @saveThese
      #  if char == symbol
      #    @parsedElementsOfType[char] << [blockNumber, secondFloat, extra] # ltodo put allReceievdP2P here, etc :)
      #    #print "yea got one #{char}!\n", token
      #  end
      #end
      
      if blockNumber == :nonBlock
        if symbol == "!" #START
          if @start
            print "whoa duplicated START!!! -- ok if you had a CS restart\n" # not sure if you should reset the start time or not--I'd guess not
          else
            @start = secondFloat
          end
        elsif symbol == ';' # bittorrent start
          if @start
               print 'bad'
          else
             @start = secondFloat
          end
        elsif symbol == "#" and !@end # done with whole file
          @end = secondFloat
	elsif symbol == 'B' and !@end # bitTorrent Done
	  @end = secondFloat # ltodo do we use this?
          @total_end = secondFloat # hacky hacky hacky
        elsif symbol == '*'
          @logFinished = true
        elsif symbol == 'T' # only one of these -- means "all files finished" :)
          @total_end = secondFloat
        else
          # might be p2p served, redundant END, or somefin ltodo
        end
      end
      
      if symbol == "+" # from peers
        @allReceivedP2P << [secondFloat, extra.to_f]
      elsif symbol == "o" || symbol == "_" # from origin
        @allReceivedHost << [secondFloat, extra.to_f]
      elsif symbol == ">" # p2p served
        @allServedP2P << [secondFloat, extra.to_f]
      end
    else
      # non token
    end
  end
  
  
  def totalDownloadTimeAllFilesDownloaded
    if ! @start
      print "ERROR no start for #{@filename} returning -99\n"
      return nil
    end
    
    if ! @total_end 
      print "ERROR no TOTAL END for #{@filename} -- maybe re run graphs when they're all done?"
      return nil
    end
    
    return @total_end - @start
  end
  
  # ltodo md5 (extensions) if they exist or something [not bad]
  
  def totalDownloadTime
    if @end.nil?
      print "ACK! #{@filename} failed downloading, I think!? That is odd it never actually finished!\n"
    end
    
    if ! @start
      print "ERROR no start for #{@filename} returning -99\n"
      return nil
    end
    
    if ! @end 
      print "ERROR NO END for #{@filename} -- maybe re run graphs when they're all done?"
      return nil
    end
    
    return @end - @start
  end
  
  
end

class SingleLogParser
  

    @@doScansWithTwoExtra = [
        [  /.*post opendht rm.*failure in ([\d\.]*)s.*uid:(.*):/ , ['a', 'Post OpenDHT Remove (failed)']],
        [  /.*post opendht rm.*success in ([\d\.]*)s.*uid:(.*):/ , ['r', 'Post OpenDHT Remove (success}']],
        [  /.*post opendht set.*success in ([\d\.]*)s.*uid:(.*):/ , ['s', 'post opendht Set (success)']], 
        [/.*post opendht set.*failure in ([\d\.]*)s.*uid:(.*):/ , ['b', 'post opendht Set (failed)']], 
    	  [/.*post opendht request.*success in ([\d\.]*)s.*uid:(.*):/ , ['g', 'Post OpenDHT request (success)']],
    	  [/.*post opendht request.*failure in ([\d\.]*)s.*uid:(.*):/ , ['c', 'Post OpenDHT request (failure)']]
    ]
    
    @@doScansWithExtra = [
    	   [/.*p2p p2p.*received (\d+)/ , ['+', 'p2p p2p received']],
    	   [/.*p2p cs.*received (\d+)/ , ['_', 'p2p cs received']],
           [/pre opendht set.*uid:(.*):/ , ['S','Pre OpenDHT Set [set begin]']],
           [/pre opendht rm.*uid:(.*):/ , ['R', 'Pre OpenDHT Remove (request remove)']], 
           [/pre opendht request.*uid:(.*):/ , ['G', 'begin OpenDHT request']]
    ]
    
    # in reality no block number means nothing to parsing :)
    @@doScansNoExtraNoBlockNumber = [
     [/Start CS normal/ , ['!', 'Start file download CS -- the beginning']],
     [/post cleanup called/ , ['*', 'log ended well']],
     [/DONE WITH WHOLE FILE/ , ["#", "Done downloading whole file"]],
     [/BT start download/, [';', 'BitTorrent Download ended']],
     [/Bittorrent download ENDED.*SUCCESS/, ['B', 'BitTorrent Download ended']],
     [/TOTALLY DONE/, ['T', 'All files in the batch completed downloading']],
     [/GOING TO P2P TOO SLOW dR/ , ['F', 'CS straight failed dR']],
     [/failed dT gauntlet/ , ['W',  'Failed dT Gauntlet -- Server slow to give a byte.']],
     [/passed dT/ , ['P', 'passed a dT gauntlet']],
     [/cs straight connected to peer/ , ['C', 'connected to origin']],
     [/file ?size.*/ , ['f', 'file size query or return']] # ltodo make this special, put it at the end the kicker is that this cannot override 
    ]
    
    @@doScansNoExtra = [
      [/.*adding new peer.*/ , ['A', 'added new peer']],
      [/trying peer/ , ['p', 'Attempt a peer listed on DHT']],
      [/p2p p2p.*bad peer.*/ , ['x', 'Bad peer: P2P attempted a peer listed in DHT, it was not live still']],
      [/p2p cs.*bad peer.*/ , ['y', 'Bad origin: P2P attempted a connection to the origin, it was not live still']],
      # TODO wasted bytes one test these two :)
      [/p2p p2p.*some not useful/ , ['U', 'p2p Not useful data!']],
      [/p2p cs.*some not useful/ , ['I', 'origin Not useful data!']],
      [/block done/ , ['D','Block Done [peer or http]']],
      [/p2p cs.*started/ , ['H','(origin) start -- attempt to connect back to origin host for block']]
    ]
    # necessary as distinct, currently, for some reason
    @@doScansNoBlockYesExtra = [
      [/.*p2p server.*just successfully queued (\d+)B/ , ['>', 'p2p served']],
      [/cs straight.*received (\d+)B/ , ['o', 'cs straight received']]
    ]
    
    # create legend
    @@legendOut = {}
    for hash in [@@doScansNoBlockYesExtra, @@doScansNoExtra, @@doScansNoExtraNoBlockNumber, @@doScansWithExtra, @@doScansWithTwoExtra] do
      hash.each { |regex, settingsForIt|
        char = settingsForIt[0]
        description = settingsForIt[1]
        raise 'duplicate ' + char if @@legendOut[char]
        @@legendOut[char] = description
      }
    end
  
    @@all_scans_with_options = [[@@doScansWithTwoExtra, :doesHaveExtra, :doesHaveSecondExtra],
				[@@doScansWithExtra, :doesHaveExtra, nil], 
				[@@doScansNoExtra, nil, nil],  
				[@@doScansNoBlockYesExtra, :doesHaveExtra, nil],
			        [@@doScansNoExtraNoBlockNumber, nil, nil]] # one of them HAS to go last or it will confuse file size with opendht and warn in error of unclosed opendht's :) 

  def initialize(filename)
    new_file_name = filename + 'cleaned.txt'
    command = "grep -v DEBUG #{filename} > #{new_file_name}"
    puts 'running', command
    system(command)
    @file = File.new(new_file_name, "r")
    @lastLine = "fake starter liner"
  end

  def legendOut
	@@legendOut # ltodo clean
  end 
  
  # returns token style stuff
  def doScan(line, regEx, hasExtra = nil, hasSecondExtra = nil)
    answerArray = line.scan(regEx) 
    if !answerArray.empty?
      if hasExtra
        extra = answerArray[0][0]
        if hasSecondExtra
          extra2 = answerArray[0][1]
        else
	  extra2 = nil
        end
      else
        extra = true
      end
      return extra, extra2
    else
      return nil
    end
  end

  def cleanup
     @file.close
     File.delete @file.path
  end
  
  attr_reader :lastLine
  
  def getNextGraphableToken
    begin
      if !@file.eof
        line = @file.readline
        @lastLine = line
      else
        cleanup
        return nil
      end
    rescue => detail
      print "weird!\n" 
      @file.close
      return nil
    end 
    return analyze_line(line)
  end
 
 
  def analyze_line line
    blockNumber  = :nonBlock
    
    # note--we don't have to worry about DEBUG lines since we filter them out using grep
    answerArray = line.scan(/^(\d+\.\d+)/)
    if answerArray.length != 0
      timeIn = answerArray[0][0].to_f
    else
      if line.length > 3 # skip blanks :)
        print "weird line no time:", line if $VERBOSE
      end
      return :nonToken
    end
    
    # look for a generic blockNumber
    answerArray = line.scan(/.*block (\d+).*/i)
    if !answerArray.empty?
      blockNumber = answerArray[0][0].to_i
    end
    
    for settings0 in @@all_scans_with_options do
      regexes = settings0[0]
      has_extra = settings0[1]
      has_second_extra = settings0[2]

      regexes.each { |regEx, settings|
        extra, extra2 = doScan(line, regEx, has_extra, has_second_extra)    
        if extra
          charToSetItTo = settings[0]
          description = settings[1]
#	  print "got #{line} => ", blockNumber, timeIn, charToSetItTo, description, extra, extra2, "\n" if extra if $VERBOSE
	  return blockNumber, timeIn, charToSetItTo, description, extra, extra2
        end
      }
    end

    # getting here is failure
    if line =~ /.*ERROR.*/
      print "error line:" + line
      return :nonToken
    else
      print "failed to parse", line unless line =~ /DEBUG/ if $VERBOSE
      return :nonToken
    end
  end
  
  # ltodo optimize a 'straight' download should be FAST sleep 0 on opendht set's, etc.
  def SingleLogParser.testSelf
    print "ack do"
  end
  
end


class Hash
  
  def Hash.testSelf
    intHash = {1 =>2, 3 => 3}
    assertEqual intHash.toArrayWithIntermediateZeroesByResolution(1), [[1, 2], [2,0], [3,3]]
    
    a = {1.0 => 2, 1.2 => 3}
    # fill in with blanks
    # ltodo fix assertEqual    assertEqual a.toArrayWithIntermediateZeroesByResolution(0.1), [[1.0, 2],[1.1,0],[1.2,3]]
    
  end
  
  # only converts to an array--an exploded one with zeroes
  def toArrayWithIntermediateZeroesByResolution(stepResolution) # ex. 0.1 break it into tenths -- weird, I know. ltodo not use
    if self.empty?
      print "ACK empty and you want it to go to an array with zeroes between?"
      return []
    end
    
    min = self.min[0]
    max = self.max[0]
    numberOfSteps = 1/stepResolution * (max - min)
    
    # ramp up original, so we can deal with ints [ltodo prettier solution to doing this?
    magnifiedSelf = {}
    for key, value in self
      magnifiedSelf[(key * (1/stepResolution)).to_i] = value
    end
    min = magnifiedSelf.min[0]
    max = magnifiedSelf.max[0] # avoid rounding probs :)
    output = [] # an Array
    0.upto(numberOfSteps.ceil) { |n|
      outputKey = min + n
      if magnifiedSelf.has_key? outputKey
        output << [outputKey * stepResolution, magnifiedSelf[outputKey]]
        magnifiedSelf.delete(outputKey)
      else
        output << [outputKey * stepResolution, 0] # normalize it back to its 'actual' value
      end
    }
    
    assert magnifiedSelf.length == 0
    return output
  end
  
end # ltodo move hash etc. specific stuff to here :)

class Array
  
  def onlyFromHereToHere(here, toHere)
    goodOnes = []
    for time, bytes in self
      if time >= here and time <= toHere
        goodOnes << [time, bytes]
      else
        # skip it, it's out of the time range
      end
    end
    return goodOnes
  end
  
  def sum
    sum = 0
    for element in self
      sum += element
    end
    return sum
  end
  
  def sumValues
    sum = 0
    for time, bytes in self
      sum += bytes.to_i
    end  
    return sum
  end
  
  def collapseMultipleArrays
    # assume we start with [[[1,2],[2,3]],[[1,2]]...]
    endBuckets = []
    for secondaryArrayInside in self
      for entry in secondaryArrayInside
        assert entry.length == 2 # sanity check :)
        endBuckets << entry
      end
    end
    return endBuckets
  end
  
  def flipIndexValueOfContainedDuples
    newSelf = []
    for index, value in self
      newSelf << [value, index]
    end
    return newSelf
    
  end
  
  def combineSeveralArraysToTenthsHash(theseArrays)
    newBuckets = {}
    for timePointArray in theseArrays
      for time, bytes in timePointArray # [time, bytes] tuples
        # each time goes into...the...we'll say 10 10th afore of it.
        0.upto(10)  { |tenth|
          keyTime = (time * 10).to_i # truncate
          keyTime += tenth
          keyTime = keyTime / 10.0
          newBuckets.addToKey(keyTime, bytes)
          
        }
      end
    end
    return newBuckets
    
  end
  
  def divideEachValueBy(this)
    this = this.to_f
    endArray = []
    for time, value in self
      endArray << [time, value/this]
    end
    return endArray
    
  end
end

class GraphHelper
  
  def GraphHelper.createLine(lineArray, filenameOutput, title, lineTitle, xAxisLabel, yAxisLabel, xResolution = 1, hashLabels = {})
    if lineArray.class == Hash
      lineArray = lineArray.sort
    end
    # ltodo xResolution here
    return GraphHelper.createLineOldSyntax(filenameOutput, title, lineTitle, yAxisLabel, xAxisLabel, lineArray)
  end
  
  def GraphHelper.createLineOldSyntax(toHere, title, oneLineTitle, yAxisLabel, xAxisLabel, arraysThatShouldConnect, realSpanArrayForTicks = nil, drawDots = true, connectLines = true)
    begin
      return GraphHelper.createToFileMultipleLines(toHere, title,
    yAxisLabel, xAxisLabel, [[oneLineTitle, arraysThatShouldConnect]],
    realSpanArrayForTicks, drawDots, connectLines)
    rescue Exception => e
      puts "ERROR IN WRITING LINE FILE " + toHere + title + e.to_s
    end
  end
  
  def GraphHelper.createToFileMultipleLinesWithPercentileArray(toHere, title, yAxisLabel, xAxisLabel, linesArray, percentileArray, realSpanArrayForTicks, drawDots, connectLines)
    # create an array like [1 (no 0), 0, 2 (no 3)...] from the original
    g = PointLine.new
    g.hide_dots = true
    assert percentileArray
    toHere += "_Percentile"    # note the ignored percentileArray [sigh] TODO
    GraphHelper.createToFileMultipleLines(toHere, title, yAxisLabel, xAxisLabel, linesArray, realSpanArrayForTicks, drawDots, connectLines, g)
  end  
  
  def GraphHelper.createToFileMultipleLines(toHere, title, yAxisLabel, xAxisLabel, linesArray, realSpanArrayForTicks, drawDots, connectLines, use_this_precreated_g = nil)
    toHere += "_Line.png"
    if !linesArray or linesArray.length == 0
      print "AACK NO LINES!!! CHECK!\n"
    end
    
    #as of now it assumes that @output has 'points' that correspond to from zero on
    # we want [0's corresponding number, 1's corresponding number... ] -- in @output
    g = use_this_precreated_g || PointLine.new
    for name, points in linesArray
      g.data(name, points)
    end
    realSpanArrayForTicks = [g.minimum_x, g.maximum_x]
    lengthOfXAxis = g.maximum_x - g.minimum_x # size of x 
    labels = GraphHelper.createFloatXAxisLabels(realSpanArrayForTicks, [g.minimum_x, g.maximum_x]) # ltodo: add this to gruff [?]
    if g.maximum_x == g.minimum_x
      print "ACK SINGLE POINT LINE! MEEP MEEP"
      return
    end
    
    GraphHelper.doGruffExceptDataAssignment(g, title, drawDots, connectLines, labels, lengthOfXAxis, xAxisLabel, yAxisLabel, toHere)
    return g
  end
  # ltodo gruff graph bug if you do 'write' then re-write -- very broken.
  
  def GraphHelper.doGruffExceptDataAssignment(g, title, drawDots, connectLines, labels, xAxisLength, xAxisLabel, yAxisLabel, toHere, x_min = nil, y_min = nil)
    g.title = title 
    g.minimum_value = 0
    g.hide_legend = true
    if not drawDots
      g.hide_dots = true
    end
    if not connectLines
      g.hide_lines = true
    end
    g.labels = labels  
    g.y_axis_label = yAxisLabel
    g.x_axis_label = xAxisLabel
    g.minimum_x = x_min if x_min
    g.minimum_value = y_min if y_min
    g.write(toHere)
    print "wrote gruff to #{toHere} #{Time.now.to_f}s\n"
  end  
  
  # ltodo make this a line without connect dots or what not :)
  def GraphHelper.createScatter(scatterArray, filenameOutput, title, lineTitle, xAxisLabel, yAxisLabel, xResolution = 1, hashLabels = {}, x_min = nil, y_min = nil)
    # ltodo make sure there aren't two on same line! :) yeps what then?
    # create some new lines -- one per scatter
    if scatterArray.length <= 1
      print "ERR scatter with zero or no points??? #{filenameOutput}"
      return
    end
    
    g = ScatterPlot2.new
    # ltodo integrate this initializer .......
    g.theme_white#_green_only # note must do this before data yeesh! ltodo fix :)
    # ltodo do stuff in scatter init's, nuke this if possible :)
    maxPoint = -1
    for point in scatterArray do
      g.dataSinglePoint("", point)
      maxPoint = [maxPoint, point[0]].max
    end
    
    filenameOutput += "_scatter.png"
    labels = GraphHelper.createFloatXAxisLabels([0, maxPoint], [0,maxPoint])
    # ltodoneed maxPoint to be passed in? check :)
    GraphHelper.doGruffExceptDataAssignment(g, title, true, false, labels, maxPoint, xAxisLabel, yAxisLabel, filenameOutput, x_min, y_min)
  end
  named_args :'self.createScatter'
  
  
  def GraphHelper.createBar(hashBars, filenameOutput, title, lineTitle, xAxisLabel, yAxisLabel, xResolution = 1, hashLabels = {})
    
    g = Gruff::Bar.new(800)
    g.y_axis_label = yAxisLabel
    g.x_axis_label = xAxisLabel
    g.minimum_value = 0
    g.title = title
    
    # so we expect hashBars to be {0 => 0, 1 => 2, 3 => 4 5 => 1} so lots of 'em
    # you must label the heights, apparently. That is annoying!
    # g.labels = {
    #      0 => '5/6', 
    #      1 => '5/15', 
    #      2 => '5/24', 
    #      3 => '5/30', 
    #    }
    
    if hashLabels.empty?
      fakeHash = {}
      # now we want 4 => 5 , 3 => 2 ==> :download, [0,0,2,3]
      # if it goes up to 50 bars...um...we only need like 5 labels total, or... count to max, every 50/5 have something besides ""
      magicStepIfItIsAMultipleOfThisNumberDisplayIt = (hashBars.max[0]/10.0).ceil
      0.upto(hashBars.max[0]) { |n|
        if n % magicStepIfItIsAMultipleOfThisNumberDisplayIt == 0
          fakeHash[(n * 1/xResolution).to_i] = n.to_s # ltodo take off, fix bug :)
        else
          #          fakeHash[n] = " " # ltodo take it off needing space yikes
        end # ltodo if it's zero don't draw the bar!
      }
      g.labels = fakeHash
    else
      g.labels = hashLabels
    end
    
    hashBars = hashBars.multiplyKeysBy(1/xResolution).keysToInts
    outputBars = []
    0.upto(hashBars.max[0]) { |n|
      outputBars << hashBars.keyValueOrZero(n)
    }
    
    g.hide_legend = true
    g.data(lineTitle, outputBars)
    if lineTitle != ""
      g.hide_legend = false
    end
    g.write(filenameOutput + "bar.png")
    print "wrote bar to =>", filenameOutput
    
    
  end
  
  def GraphHelper.createIntegerXAxisLabels(startEndArray, numberToSpreadItByStartsAtZero)
    normalLabels = createFloatXAxisLabels(startEndArray, [0,numberToSpreadItByStartsAtZero])
    newLabels = {}
    for key, value in normalLabels
      if not newLabels.has_key? key.to_i
        newLabels[key.to_i] = value
      end
    end
    return newLabels
  end
  
  def GraphHelper.createFloatXAxisLabels(startEndArray, columnBoundaryArray)
    start, endy = startEndArray
    startSpacing, endSpacing = columnBoundaryArray
    
    if start == endy
      print "WARNING single point detected, no labels made"
      return
    end
    assert endSpacing > startSpacing
    assert endy > start
    labelHash = {}
    outputStepSize = ((endy - start) / 5.0) # ltodo bug is using hash values that are floats :)
    
    columnCountSpan = endSpacing - startSpacing
    span = endy - start
    tickLocationStepSize = columnCountSpan / 5.0 # every that many buckets
    if span > 10
      formatString = "%d"
    elsif span > 1
      formatString = "%.01f" # single decimal place
    elsif span > 0.25 
      formatString = "%.02f" # single decimal place ltodo these may not matter, as gruff changes them  :)
    else
      formatString = "%f" # single decimal place ltodo these may not matter, as gruff changes them  :)
    end # ltodo comapre to gruff where they do this...hmm...
    
    # ltodo xmlrpc/client.rb is set to 120 now...hmm...give up after awhile, maybe?
    0.upto(5) { |n| # ltodo test is pointline [1.1, 2.1] range :)
      percentageAcross = n * 0.2
      indexNumber = startSpacing + percentageAcross * columnCountSpan
      numberThatGoesThere = percentageAcross * span + start
      labelHash[indexNumber] = formatString % numberThatGoesThere
    }
    return labelHash
    
  end
  
  def GraphHelper.testSelf
    
    GraphHelper.createCDF({1 => 5, 2 => 2, 3=> 3, 4 => 1}, "test/barcdf", "title", "linetitle", "x", "y")
    GraphHelper.createCDF({2 => 5, 4 => 5}, "test/fake", "title", "linet", "Peers up to 10", "Bytes up to 4")
    GraphHelper.createCDF({2 => 5, 4 => 5, 6 => 7}, "test/fake2", "title", "linet", "y", "x")
    GraphHelper.createBar({1 => 5, 2 => 2, 3=> 3, 4 => 1}, "test/barfake", "title", "some bars", "x", "y")
    GraphHelper.createBar({0.5 => 0.5, 0.1 => 0.1, 2.3 => 2.3}, "test/barfloatcdf", "title", "linetitle", "x", "y", 0.1, {})
    
    beginPoints = [[0,0],[2,3],[3,3]]
    createLine(beginPoints, "test/test_single", "title is title", "line title is line", "x", "y")
    # ltodo fix    writeToFileMultipleLines("test/test_multiple", "title", "y", "x axis", [["line one", [[0,0],[1,1],[2,2],[3,3]]], [["line two"], [[0,1],[1,2],[5,3]]]])
    
  end
  
  def GraphHelper.createCDF(hashBuckets, filenameOutput, title, lineTitle, yAxisLabel, xAxisLabel, labelsUnused = nil, drawPercentiles = false, flipPoints = false)
    raise 'deprecated' if drawPercentiles # ltodo clean
    
    # 2 => 5, 4 => 5  (5 2's, 5 4's)
    #   = > [0,0], [1,0], [2, .6], [3, .6], [4, 1] 
    if hashBuckets.class == Array
      hashBuckets = hashBuckets.dupleArrayToSummedHash
    end
    if hashBuckets.length <= 1
      print "ERROR giving up on cdf of one point #{filenameOutput}\n\n"
      return
      # ltodo can we still do this if not 0,0?
    end
    
    if hashBuckets.min != [0,0]   # if it doesn't contain that point
      hashBuckets[0] = 0 # even if some have zero, we need this to look like a CDF ltodo make into a gruff ruff!
    else
      print "good job your cdf has 0,0!\n"
    end
    maxKey = hashBuckets.max[0]
    total = hashBuckets.sumValues.to_f
    output = []
    
    sumSoFar = 0
    # at this point hashBuckets ate 0.5 -> 3, 1 -> 1
    hashBuckets.sort.each { |time, value|
      additionThisOneProvides = value / total # ltodo continue
      sumSoFar += additionThisOneProvides 
      if flipPoints
        output << [sumSoFar, time]
      else
        output << [time, sumSoFar]
      end
    }
    filename = filenameOutput + "_CDF"
    g = createLine(output, filename, title + " CDF", lineTitle, xAxisLabel, yAxisLabel, 1)
    #    g.maximum_value = 1 # todo
    #    g.write(filename + ".png")
    return g
  end  
  
end
if $0 == __FILE__
  require 'constants'
  subj = ClientLogContainerWithStats.new(ARGV[0])
  print subj.end
end
