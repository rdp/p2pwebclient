#!/usr/bin/ruby
# ltodo the opendht graphs are lop-sided...fix
# ltodo average speed/active client/instantaneous second graph :) [pretty similar to total throughput]
# ltodo fascinating would be a 'speed per client' so you can see if it scales or not
# ltodo average load on just the p2p's back and forth :)
# ltodo does this do things twice?  Teh parsing?  That is bad :)

# graph of 'opendht get to size', opendht scatter
# upload quantity to download speed, upload max speed to upload quantity
# lodo on do graphs just quick check
# ltodo tell opendht about 'I already quit with you!' and it keeps
# sending it back :)
require 'unique_require'
require __FILE__
require 'constants'
require 'new_graphs.rb'
require 'pp'
require 'individual_graph.rb'
require 'graphHelpers.rb'
require 'vary_parameter_graphs'

$beenHere = true
$doIndividuals = true 

class String
 alias :contains? :include? # I like contains much better :)
end

class RunGrapher # should be called MultipleRunsSameSettingGrapher
  attr_reader :dirName  
  attr_reader :arrayContainingArraysOfClientsPerRun
 
  def self.get_log_files_list runName
     glob_string = "../logs/**/#{runName}_*/peer*.log.txt" # ignore  extra parameters..., allows for 'super runs' , too of submitting a 'higher' spec... i.e. run_10 incorporated run_10_1 an drun_10_3-- all in one
     files = Dir.glob(glob_string)
     assert(files.length > 0, "ACK I THINK RUN DID NOT WORK no files
     found! #{runName} #{glob_string}")
     files
  end

  def initialize(runs, outputName = runs.join('_'), already_created_runs_that_want_to_be_combined = nil)
    assert runs.class == Array && runs[0].class == String
    @runs = runs
    @dirName = RunGrapher.pictureDirectory + "/single_run_pics/#{outputName}"[0..35]
    @outputNameRequested = outputName
    Dir.mkPath(@dirName)
    @templateName = @dirName + "/"
    @arrayContainingArraysOfClientsPerRun = []
    @graphSmoothFactor = 20 # tenths around itself... this can be rather a slowdown, if I remember correctly, if set too high
    @allClientsInOne = [] # most want
    @spanDuplesPerRunArray = []
    startTimes = []
    endTimes = []
    if already_created_runs_that_want_to_be_combined
      assert already_created_runs_that_want_to_be_combined.class == Array
      assert already_created_runs_that_want_to_be_combined[0].class == RunGrapher
      @arrayContainingArraysOfClientsPerRun = []
      already_created_runs_that_want_to_be_combined.each{|run| @arrayContainingArraysOfClientsPerRun << run.arrayContainingArraysOfClientsPerRun[0]} # I suppose we could rip out more but this is the main part :)
    else
      for run in runs
        files = RunGrapher.get_log_files_list run # ignore  extra parameters..., allows for 'super runs' , too of submitting a 'higher' spec... i.e. run_10 incorporated run_10_1 an drun_10_3-- all in one
        thisRunsClientsArray = []
        for filename in files
          client = ClientLogContainerWithStats.new(filename)
          thisRunsClientsArray << client
        end
        @arrayContainingArraysOfClientsPerRun << thisRunsClientsArray
      end
    end

    for run in @arrayContainingArraysOfClientsPerRun
      startTimesThisRun = []
      endTimesThisRun = []
      for client in run
        @allClientsInOne << client
        if !client.start
            print "ERROR client has not a start " + filename + " has not a start"
        end
        startTimes << client.start if client.start
        startTimesThisRun << client.start if client.start 
        if not client.logFinished
          print "ERROR SEEDO client has not a log end! "  + filename.to_s + client.subject.lastLine.to_s + "\n\n\n\n"
        end
        
        if not client.end
          print "ERROR SEEDO client has not a file downloading end "  + filename.to_s + client.subject.lastLine.to_s + "\n\n\n\n"
        else 
          endTimes << client.end
          endTimesThisRun << client.end
        end
      end
      startFrame = startTimesThisRun.percentile 20
      endFrame = endTimesThisRun.percentile 80
      @spanDuplesPerRunArray << [startFrame, endFrame]       # unused, I think ltodo get rid of if not using
      
    end
    if endTimes.length < startTimes.length
      print "ERROR SOME FINISHED NOT!!!\n\n\n"
    end
    print "%d started, %d ended\n" % [startTimes.length, endTimes.length]
    
  end
  
  def RunGrapher.testSelf
   print "ignore errors"
   subject = RunGrapher.new(['fakerun']) 
   print "dont ignore errors"
   assertEqual combineSeveralArraysToHash([[[1.0, 1],[2.0, 2], [1.0, 0.5]], [[1.0, 0.1]]]), {1.0 => 1.6, 2.0 => 2}
   assertEqual subject.combineSeveralArraysToTenthsSummedHash([[[1.0, 3]]]), {1.5=>3,
    0.7=>3,
     1.2=>3,
      0.9=>3,
       1.1=>3,
        1.4=>3,
         0.8=>3,
           0.6=>3,
            1.0=>3,
             1.3=>3}
   print "RunGrapher testself done"
    
  end
  
  def RunGrapher.pictureDirectory
    return "../" + Socket.gethostname + "_pics"
  end
  
  def goPercentFromClients(filenameOutput = @templateName + "percentFromClients")
    rawFilename = filenameOutput + ".raw.txt"
    createPercentFromClients(rawFilename)  
    graphPercentFromClients(rawFilename, filenameOutput)
  end
  
  def createPercentFromClients(filenameOutputRaw = @templateName + "percentFromClients" + ".raw.txt")
    all = []
    for client in @allClientsInOne
      all << [client.percentFromPeers, 1]
    end
    gotBack = LineWithPointsFile.writeAndReadSingle(filenameOutputRaw, "Percent from peers", all)
    # assertEqual gotBack, all works
    return gotBack
    
  end
  
  
  def getDeathMethodsAveraged
    allMethods = {}
    allMethods['http_straight'] = 0
    allMethods['dR'] = 0
    allMethods['dT'] = 0
    for client in @allClientsInOne
      allMethods.addToKey(client.endMethod, 1)
    end
    allMethods = allMethods.divideValuesBy(@runs.length)
    # ltodo use these '% age' graphs :)
  end

  def graphPercentFromClients(rawFilename, filenameOutput)
    points = LineWithPointsFile.readSingleToArray(rawFilename) # at this point we have 1=> .5 1=> .9, and apparently we WANT .5 => 1 .9 => 1
    g = GraphHelper.createCDF(points, filenameOutput, "Percent received via P2P", " ", "Percent from peers ", "Peer percentage", nil, false, true)
  end

  def goAllP2PTraffic(rawFilename, filenameOutput)
       raw = filenameOutput + ".raw.txt"

  end
  
  def goTotalThroughPut(filenameOutput)
    raw = filenameOutput + ".raw.txt"
    createTotalThroughPutsReturnPartial(raw, :write_to_file => true, :include_host_bytes => true, :include_peer_received_bytes => true)
    graphTotalThroughPut(raw, filenameOutput)
  end
  
  def totalThroughPutPointsPartial
    createTotalThroughPutsReturnPartial(:include_host_bytes => true, :include_peer_received_bytes => true).flipIndexValueOfContainedDuples # ltodo take out ending
  end
  
  def allReceivedPointsPartialP2P
    createTotalThroughPutsReturnPartial(:include_peer_received_bytes => true).flipIndexValueOfContainedDuples
  end
  
  def allServedPointsPartialP2P
    createTotalThroughPutsReturnPartial(:include_peer_send_bytes => true).flipIndexValueOfContainedDuples
  end
  
  def createTotalThroughPutsReturnPartial(filenameOutputRaw = nil, include_peer_received_bytes = false, include_host_bytes = false, include_peer_send_bytes = false, write_to_file = false) # ltodo combine with other functions that do the same thing :) maybe memoize
    raise unless include_peer_received_bytes || include_host_bytes || include_peer_send_bytes
    filenameOutputRaw ||= @templateName + "total_throughput" + ".#{include_host_bytes}.raw.txt"
    allReceivedArrays = [] 
    totalBytesReceivedFromPeersAcrossAllRuns = 0 if include_peer_received_bytes
    totalBytesServedFromPeersAcrossAllRuns = 0 if include_peer_send_bytes
    totalBytesUploadedByServerAcrossAllRuns = 0 if include_peer_received_bytes
    # we only want [20-100%]
    pointsWithoutTheEdges =  []
    @arrayContainingArraysOfClientsPerRun.each_with_index { |run, index| # ltodo every each_with_index => hash muhaha 
        spanDuple = @spanDuplesPerRunArray[index]
        nonpointsWithoutTheEdges = []
        for client in run
                nonpointsWithoutTheEdges += client.allReceivedP2P if include_peer_received_bytes
                nonpointsWithoutTheEdges += client.allReceivedHost if include_host_bytes
                nonpointsWithoutTheEdges += client.allServedP2P if include_peer_send_bytes
                if write_to_file
                  assert include_peer_received_bytes and include_host_bytes
                  allReceivedArrays << client.allReceivedP2P
                  allReceivedArrays << client.allReceivedHost
                end
        end
        pointsWithoutTheEdges += nonpointsWithoutTheEdges.onlyFromHereToHere(0,10000000)#spanDuple[0], spanDuple[1])
    }
# they need to be combined now...i.e. 2.3 6K, 2.7 8K => 2: 15K
    pointsWithoutTheEdges = combineSeveralArraysToTenthsSummedHash([pointsWithoutTheEdges])
    pointsWithoutTheEdges = pointsWithoutTheEdges.toArrayWithIntermediateZeroesByResolution(0.1)
    pointsWithoutTheEdges = pointsWithoutTheEdges.divideEachValueBy(@arrayContainingArraysOfClientsPerRun.length)

    # now--we want to write out "all" the points, not just the from here to here ones. 
  
    # do some stats, too, why not? ltodo split this out
    for client in @allClientsInOne
      for time, bytesReceived in client.allReceivedP2P
        totalBytesReceivedFromPeersAcrossAllRuns += bytesReceived
      end if include_peer_received_bytes
      
      for time, bytesReceived in client.allReceivedHost
        totalBytesUploadedByServerAcrossAllRuns += bytesReceived
      end if include_host_bytes
      
      for time, bytesReceived in client.allServedP2P
        totalBytesServedFromPeersAcrossAllRuns += bytesReceived
      end if include_peer_send_bytes
    end
    
    if write_to_file
      allReceivedEver = combineSeveralArraysToTenthsSummedHash(allReceivedArrays, @graphSmoothFactor)
      newBuckets = allReceivedEver.toArrayWithIntermediateZeroesByResolution(0.1)
      newBuckets = newBuckets.divideEachValueBy(@arrayContainingArraysOfClientsPerRun.length) # we should be 'too high' :)
      out = LineWithPointsFile.writeAndReadSingle(filenameOutputRaw, "total throughput receiveds", newBuckets)
    end
    #totalBytesReceivedFromPeersAcrossAllRuns /= @runs.length.to_f # why not be total total :)
    #totalBytesUploadedByServerAcrossAllRuns /= @runs.length.to_f
    print "total bytes received by peers  #{totalBytesReceivedFromPeersAcrossAllRuns/ @runs.length.to_f} average per run\n" if include_peer_received_bytes
    print "bytes UPloaded by server #{totalBytesUploadedByServerAcrossAllRuns/ @runs.length.to_f} average per run\n" if include_host_bytes
    print "bytes UPloaded by peers #{totalBytesServedFromPeersAcrossAllRuns/ @runs.length.to_f} average per run\n" if include_peer_send_bytes
    
    @totalBytesReceivedFromPeersAcrossAllRuns = totalBytesReceivedFromPeersAcrossAllRuns if include_peer_received_bytes
    @totalBytesUploadedByServerAcrossAllRuns = totalBytesUploadedByServerAcrossAllRuns if include_host_bytes
    @totalBytesServedFromPeersAcrossAllRuns = totalBytesServedFromPeersAcrossAllRuns if include_peer_send_bytes
    return pointsWithoutTheEdges
  end  

  attr_reader :totalBytesReceivedFromPeersAcrossAllRuns, :totalBytesUploadedByServerAcrossAllRuns, :totalBytesServedFromPeersAcrossAllRuns
  
  named_args :createTotalThroughPutsReturnPartial
  
  def graphTotalThroughPut(filenameRaw, filenameOutput) # ltodo use new line :)
    graphThis = LineWithPointsFile.readSingleToArray(filenameRaw)
    GraphHelper.createLineOldSyntax(filenameOutput, "Total system throughput", "Bytes Received", "Bytes / S", "Time (s)", graphThis)
  end
  
  def multipleDHTPuts
    return createOpenDHT()[0].sort
  end
  
  def multipleDHTRemoves
    return createOpenDHT()[2].sort
  end
  
  def multipleDHTGets
    return createOpenDHT()[1].sort
  end

  def goOpenDHTScatters(filenameOutput)
   for type, name in {'G' => 'Gets', 'S' => 'Sets', 'R' => 'Removes' } do
       goOpenDHTSomethingScatter(filenameOutput + name, type, name)
   end
  end
 
  def goOpenDHTSomethingScatter(filenameOutput, type, name)
     raw = filenameOutput + ".raw.txt"
     createOpenDHTSomethingTimes(raw, type)
     graphOpenDHTSomethingTimes(raw, filenameOutput, name) # this is scatter
  end

  def createOpenDHTSomethingTimes(raw, type)
   allGets = []
   for client in @allClientsInOne
       for entry in client.getAllOpenDHTItems
           if entry.type == type and entry.endy
               allGets << [entry.start, entry.endy - entry.start]
           end
       end
   end

   parsedOut = LineWithPointsFile.writeAndReadSingle(raw, "dht gets by start time", allGets)
   #assertEqual parsedOut, allGets
   allGets

  end # ltodo this whole thing is so ugly!!! and not DRY!!!

  def graphOpenDHTSomethingTimes(raw, filenameOutput, type)
        points = LineWithPointsFile.readSingleToHash(raw)
        GraphHelper.createScatter(points, filenameOutput, :title => "OpenDHT #{type}", :lineTitle => "nothing! there are no lines!", :xAxisLabel => "Start Time (s)", :yAxisLabel => nil, :x_min => 0, :y_min => 0) # ltodo fix the nothing
  end

# ltodo a graph of bytes from the peers [numbers that move up, with vary parameter]
  
  def goOpenDHT(filenameOutput)
    raw = filenameOutput + ".raw.txt"
    createOpenDHT(raw)
    RunGrapher.graphOpenDHT(raw, filenameOutput)
  end

  def createOpenDHT(rawFilename = @templateName + "multipleDHTTriple.raw.txt")
    allGetsByTime = {}
    allPutsByTime = {}
    allRemovesByTime = {}
    for client in @allClientsInOne
      for entry in client.getAllOpenDHTItems

        # G is get
        
        assert entry.start
# it's ok for it to not come back, in the case of an interrupted thread [or is it???] tlodo
        
        if entry.endy.nil?
          print "E"#RROR with DHT something--never came back! #{text}, #{entry}"
          #          entry.endy = entry.start + 120
          next
        end
        howLong = (entry.endy - entry.start)
        if entry.type == "G"
          allGetsByTime.addToKey(howLong, 1.0)
        elsif entry.type == "S"
          allPutsByTime.addToKey(howLong, 1.0)
        else
          assert entry.type == "R"
          allRemovesByTime.addToKey(howLong, 1.0)
        end
        
      end 
    end
    if allPutsByTime.length == 0: print "ACK! this had better be CSno puts means no p2p impossible!??" end 
    
    if allGetsByTime.length == 0
      print "ack! no gets means no p2p receive action at all recorded"
    end
    
    toWrite = [["Puts", allPutsByTime.sort], ["Gets", allGetsByTime.sort], ["Removes", allRemovesByTime.sort]]
    a = LineWithPointsFile.new(rawFilename) #ltodo clean
    a.write(toWrite)
    return allPutsByTime, allGetsByTime, allRemovesByTime
    
  end
  
  def RunGrapher.graphOpenDHT(rawFilename, filenameOutput)
    graphableLines = LineWithPointsFile.readToArrayHashes(rawFilename)
    for line in graphableLines
      name = line[0]
      points = line[1]
      if points.length == 0
        print "ack no opendht points at all for dht type" + name
      end
      graph = GraphHelper.createCDF(points, filenameOutput + name, "OpenDHT " + name, " Line", " ", "Time (seconds)")  # ltodo move points to end
    end
  end  

  def goTotalPeersLatencyFromDHT(filenameOutput = @templateName + "totalPeerLatency")
   raw = filenameOutput + ".raw.txt"
   createSinglePointScatter('$', raw, "Total DHT for all rounds, to start time")
   graphSinglePointScatter(raw, filenameOutput, "Return Time (s)", "Query duration (s)")
  end

  def createSinglePointScatter(char, rawFilename, nameForTextFile)
        allPoints = []
        for client in @allClientsInOne
                # they are long, within each one [blockNumber, secondFloat, extra
                # assume it should be (extra == x, time == y)
                for newPoint in client.savedItems[char]
                        incoming =  [newPoint[1], newPoint[2]] # currently (y,x) ??? ltodo
                        allPoints << incoming
                end
        end
        parsedOut = LineWithPointsFile.writeAndReadSingle(rawFilename, nameForTextFile, allPoints)
  end

  def graphSinglePointScatter(rawFilename, outputFilename, xTitle, yTitle)
        graphableLines = LineWithPointsFile.readToArrayHashes(rawFilename)
        assert graphableLines.length == 1
        for line in graphableLines
            name = line[0]
            points = line[1]
            graph = GraphHelper.createScatter(points, outputFilename, name, "blank!", xTitle, yTitle)
        end
  end

  def goClientStartToServed(filenameOutput)
        raw = filenameOutput + ".raw.txt"
        points = createClientStartToServed(raw)
        graphcreateClientStartToServed(raw, filenameOutput)
  end
  
  def createClientStartToServed(raw)
        startServedTimes = []
        for client in @allClientsInOne
            incoming = [client.start, client.sumServed]
            startServedTimes  << incoming
        end
    parsedOut = LineWithPointsFile.writeAndReadSingle(raw, "client start to served", startServedTimes)
    # ltodo check this with larger run assertEqual parsedOut, startServedTimes
    startServedTimes

  end
 
  def graphcreateClientStartToServed(raw, filenameOutput)
        times = LineWithPointsFile.readSingleToHash(raw)
        GraphHelper.createScatter(times, filenameOutput, "Amount served per client", "nothing!", "Start Time (s)", "Bytes served") # ltodo fix the nothing
  end

  def goClientDownloadToStartTimes(filenameOutput)
    raw = filenameOutput + ".raw.txt"
    createClientDownloadToStartTimes(raw)
    graphClientDownloadToStartTimes(raw, filenameOutput)
  end


  def goClientDownloadAllFilesToStartTimes(filenameOutput)
    raw = filenameOutput + ".raw.txt"
    createClientDownloadToStartTimes(raw)
    graphClientDownloadToStartTimes(raw, filenameOutput, 'Start Time to End Time (last file)')
  end

  
 # ltodo vary_parameters on amount served per peer (fairness)
  def createClientDownloadToStartTimes(rawFilename, use_total_for_all_files = false)
    downloadTimes = []
    total_failed = 0
    for client in @allClientsInOne
      begin
        value = use_total_for_all_files ? client.totalDownloadTimeAllFilesDownloaded : client.totalDownloadTime
        if value
          downloadTimes << [client.start, value]
        else
          print "ERROR ERROR no download time #{use_total_for_all_files} total failed: #{total_failed += 1}!" 
        end
      rescue => detail
        print "ERROR client non end" + detail.to_s
      end
    end
    parsedOut = LineWithPointsFile.writeAndReadSingleToHashInt(rawFilename, "client start and end times", downloadTimes) # yields sums
    # fails yet shouldn't (works -- ltodo)  assertEqual parsedOut, downloadTimes.toSummedByIntegerHash.sort # works if agove is array
    
  end
  
  def graphClientDownloadToStartTimes(raw, filenameOutput, name = "Start Time to End Time")
    downloadTimes = LineWithPointsFile.readSingleToHash(raw)
    GraphHelper.createScatter(downloadTimes, filenameOutput, name, "", "Start Time (s)", "Download Time (s)")
  end
  
  # ltodo these are sometimes awfully similar...
  
  def goClientDownloadTimes(filenameOutput) # CDF
    rawFilename = filenameOutput + ".raw.txt"
    createClientDownloadTimes(rawFilename)
    graphClientDownloadTimes(rawFilename, filenameOutput)
  end
  
  def goClientTotalDownloadTimesAllFiles(filenameOutput)
    rawFilename = filenameOutput + ".raw.txt"
    createClientDownloadTimes(rawFilename, true)
    graphClientDownloadTimes(rawFilename, filenameOutput, 'Peer download times (for all files)')
  end
  
  def createClientTotalDownloadTimes
    createClientDownloadTimes(nil, true)
  end
  
  def createClientDownloadTimes(rawFilename = nil, use_total_all_files = false)
    rawFilename ||= @templateName   + "downloadTimes#{use_total_all_files}" + ".raw.txt"
    allTimes = {}
    for client in @allClientsInOne
      begin
        value = if use_total_all_files then client.totalDownloadTimeAllFilesDownloaded else client.totalDownloadTime end
        if value
          allTimes.addToKey(value.truncateToDecimal(2), 1)
        else
          print "WARNING no downloadtime!"
        end
      rescue => detail
        print "ack client no download time!!!ERROR" + detail.to_s # ltodo not allow, or count these and report them...
      end
    end
    if allTimes.length == 0
      print "NONE APPEARED TO HAVE FINISHED\n"
    end
    parsedOut = LineWithPointsFile.writeAndReadSingleToHash(rawFilename, "download points", allTimes.sort)
    # ltodo could work :) ->    assertEqual allTimes, parsedOut
    return parsedOut
  end
  
  def graphClientDownloadTimes(rawFilename, filenameOutput, name = "Peer download times")
    parsedOut = LineWithPointsFile.readSingleToHash(rawFilename)
    GraphHelper.createCDF(parsedOut, filenameOutput, name, "percent", " ", "Download Time (seconds)")  # ltodo move points to end
  end
  
  def goClientTotalUploadCDF(filenameOutput)
    rawFilename = filenameOutput + ".raw.txt"
    createClientTotalUpload(rawFilename)
    graphClientTotalUploadCDF(rawFilename, filenameOutput)
  end
  
  def createClientTotalUpload(rawFilename = @templateName + "upload_client_total_upload" + ".raw.txt")
    # this is 'total bytes per client uploaded'
    all = [] # keep it a straight array so that we can do percentiles easily on it, later
    for client in @allClientsInOne
      all << [client.sumServed, 1]
    end
    parsedOut = LineWithPointsFile.writeAndReadSingle(rawFilename, "clientsumuploaded per client", all)
    assertEqual parsedOut, all
    all
    
  end
  
  def graphClientTotalUploadCDF(raw, out)
    points = LineWithPointsFile.readSingleToHash(raw) # ltodo CDF ignore y axis label :)
    GraphHelper.createCDF(points, out, "Client Upload amount", "", nil, "Bytes uploaded")  # ltodo move points to end
  end
  
  def goServer(filenameOut)
    rawFilename = filenameOut + ".raw.txt"
    createServerBytesPerSecondReturnPartial(rawFilename)
    graphServer(rawFilename, filenameOut)
  end
  
  def allServerServedPointsPartial
    createServerBytesPerSecondReturnPartial().flipIndexValueOfContainedDuples
  end
  
  def createServerBytesPerSecondReturnPartial(rawFilename = @templateName + "server_total" + ".raw.txt")
    allEntries = []
    partialServedPoints = []
    @arrayContainingArraysOfClientsPerRun.each_with_index { |run, index|
        spanDuple = @spanDuplesPerRunArray[index]
        nonpointsWithoutTheEdges = []
        for client in run
                nonpointsWithoutTheEdges += client.allReceivedHost
        end
        toAdd =  nonpointsWithoutTheEdges.onlyFromHereToHere(spanDuple[0], spanDuple[1]) 
        partialServedPoints += nonpointsWithoutTheEdges.onlyFromHereToHere(spanDuple[0], spanDuple[1])
    }
    partialServedPoints  = combineSeveralArraysToTenthsSummedHash([partialServedPoints]).toArrayWithIntermediateZeroesByResolution(0.1).divideEachValueBy(@arrayContainingArraysOfClientsPerRun.length)

# ltodo combine with above loop! 
    for client in @allClientsInOne
      allEntries << client.allReceivedHost
    end # ltodo fake server should NOT propagate the size :)
    collapsed = allEntries.collapseMultipleArrays
    buckets = combineSeveralArraysToTenthsSummedHash([collapsed], @graphSmoothFactor)
    # now add zeroes-- zeroes count this time :)  ltodo should zeroes count for others, perhaps, too?
    newBuckets = buckets.toArrayWithIntermediateZeroesByResolution(0.1)
    newBuckets = newBuckets.divideEachValueBy(@arrayContainingArraysOfClientsPerRun.length) # we should be 'too high' :) this will bring us down to size
    newBucketsCopy = LineWithPointsFile.writeAndReadSingle(rawFilename, "server received by peer points", newBuckets)
    # fails in error    assertEqual newBucketsCopy, newBuckets

    return partialServedPoints
  end # func  
  
 # ltodo a scatter graph of when the various ones happened of dT vs. dR, versus straight 
  def graphServer(rawFilename, filenameOutput)
    # right now a byte received at second "x.5" spreads its influence to itself and the preceding second. Yea.
    buckets = LineWithPointsFile.readSingleToArray(rawFilename)
    begin
      GraphHelper.createLine(buckets, filenameOutput, "Main Server load", "Main Server", "Time (s)", "Bytes / S", 0.1)
    rescue NoMethodError
      print "SEEDO ACK! NO SERVER STUFF!"
    end
  end
  
  def combineSeveralArraysToTenthsSummedHash(combineThese, tenthsWide = 10)
    combined  = RunGrapher.combineSeveralArraysToHash(combineThese)
    return combined.toTenthsSummedHash(tenthsWide)
  end
 
  def RunGrapher.combineSeveralArraysToHash(theseArrays)
    newBuckets = {}
    for timePointArray in theseArrays
       for time, bytes in timePointArray 
        newBuckets.addToKey(time, bytes)
       end
    end
    return newBuckets
  end
  
  # ltodo give to gruff
  
  def createAllIndividuals
    for client in @allClientsInOne
      client.createIndividual @dirName
      print "."
      STDOUT.flush
    end
  end
  
  # ltodo necessary? timeout on connect to origin, peers.  If they're not good in like...30S...man...
  # Todo if opendht times out...basically it nukes every thread!  Like...nukes it! check if the patch works :)
  def doAll
    # this is the same as openDHT scatters normal goTotalPeersLatencyFromDHT
     goOpenDHTScatters(@templateName + "opendht_scatter")
     goClientTotalUploadCDF(@templateName + "upload_client_total_upload")
     goClientDownloadTimes(@templateName + "downloadTimes")
     goClientTotalDownloadTimesAllFiles(@templateName + 'allDownloadTimes')
     goClientDownloadToStartTimes(@templateName + "downloadToStartTimes")
     goClientDownloadAllFilesToStartTimes(@templateName + 'downloadAllFilesToStartTimes')
     goClientStartToServed(@templateName + "clientStartToServed")
     goOpenDHT(@templateName + "opendht")
     goPercentFromClients
     getDeathMethodsAveraged
     Dir.createIndexFile(@dirName)
     system("start #{@dirName.gsub('/','\\''')}")
     if $doIndividuals  
       createAllIndividuals
     end
     goServer(@templateName + "server_total")
     goTotalThroughPut(@templateName + "total_throughput") # ltodo optimize (?)
     VaryParameter.doStatsSingleRun([@outputNameRequested], [self], @dirName) # our output directory tlodo only calculate them once
     VaryParameter.doStatsSingleRun([@outputNameRequested], [self]) # normal "stats all go here" directory
     Dir.createIndexFile(@dirName)
  end
  
  def RunGrapher.doAllNoCalculate(runs, outputName = runs.join('_'))
        assert runs.class == Array
        dirName = RunGrapher.pictureDirectory + "/single_run_pics/#{outputName}"
        outputNameRequested = outputName
        templateName = dirName + "/"
        RunGrapher.graphOpenDHT stemplateName + 'opendht.raw.txt'
  end
    
  def RunGrapher.doTestRun(runNumber) # incomplete
    templateName = "test/pics/#{runNumber}/test_run_#{runNumber}_"
    a = RunGrapher.new([runNumber])
    #  a.goServer(templateName + "server_total")
    #  a.goTotalThroughPut(templateName + "total_throughput")
    #  a.goClientTotalUploadCDF(templateName + "upload_client_total_upload_cdf")
    #  a.goClientDownloadTimes(templateName + "downloadTimesCDF")
    #  a.goOpenDHT(templateName + "opendht")
    a.goClientDownloadToStartTimes(templateName + "downloadToStart")
    #a.goPercentFromClients
    #getDeathMethodsAveraged
    print "done with test graphs of run #{runNumber}"
    
  end
  
  # ltodo do a run 'hammering' a server on localhost, try to match it muhhaa [or against apache+wget on localhost is that possible?]
  
  # ltodo scatters make sure just keep all data :) data is cheap!
  # ltodo look for anything that is integer based -- data is cheap!!!!!
  
end # class


class Hash
  
  def toTenthsSummedHash(howManyTenthsTotal = 10)# this doesn't change the values but just 'spreads' them all out int he new one, with finer granularity (like having .1.1.1.1.1 instead of just .1 which is...still the same..mostly)
    howManyTenthsTotal = howManyTenthsTotal.to_f
    newBuckets = {}
      for time, bytes in self # [time, bytes] hashes
        # each time goes into...the...we'll say 10 10th afore of it.
        bytes /= (howManyTenthsTotal/10)
        1.upto(howManyTenthsTotal)  { |tenth|
          keyTime = (time * 10).to_i # truncate to tenth
          keyTime += tenth - howManyTenthsTotal/2 # make it 'balanced in the middle i.e. fill from 2.5 to 3.5 for 3.0
          keyTime = keyTime / 10.0#howManyTenthsTotal.to_f
          if keyTime >= 0 # ignore if before zero
          #  print "from #{time}s #{bytes}b adding #{keyTime}s, #{bytes}b\n"
            newBuckets.addToKey(keyTime, bytes)
          else
            # print "ltodo what about negatives??"
          end
        }
      end
    return newBuckets
  end
end


class Array
  def percentile thisPercentile
    if self.length == 0
      print "ack! WARNING percentile on an array with nothing in it!"
      return nil
    end
    
    position = self.length * thisPercentile / 100 # round down why not?
    if self.length > 1
      arrayToUse = self.sort
    else
      arrayToUse = self
    end
    return arrayToUse[position]
  end
  
end

# ltodo put in a run and 'hard code' the right answers, for a test :) 
if __FILE__.include?($0) or debugMe 'singleMultipleGraphs' # ltodo change these all to .rb
  if ARGV.length > 0
    if(ARGV == ['--help'])
        puts 'run as name1 name2 # all part of the same run'
        exit
    end

    $doIndividuals = true
    a = RunGrapher.new(ARGV)
    a.doAll
  else
    #    RunGrapher.doTestRun(3144)
    #RunGrapher.testMultiples
    #RunGrapher.doTestRun("grundled-200-lab-2")
    a = RunGrapher.new(['test2-10-v2_0_0.5', 'test2-10-v2_1_0.5'])
    a.doAll
  end
end
# vltodo run it with 'super fast local' fast server -- first few clients are faster (?) optimize it that way:)
