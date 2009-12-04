#!/usr/bin/ruby
require 'rubygems'
require 'RMagick'
#$skip_gruff = true
$skip_opendht_processing = true



# ltodo average speed/active client/instantaneous second graph :) [pretty similar to total throughput]

# graph of 'opendht get to size got', opendht scatter
# upload quantity to download speed, upload max speed to upload quantity
#
#
#
require './unique_require'
$LOADED_FEATURES << __FILE__ # fake that we've been here
$LOADED_FEATURES << File.expand_path(__FILE__)
require './constants'
require 'new_graphs.rb' unless $skip_gruff
require 'pp'
require 'individual_graph.rb'
require 'graphHelpers.rb'
require 'vary_parameter_graphs'

require 'rbconfig'
if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ # jruby friendly
  require 'forky_replacement_fake.rb'
end

$doIndividuals = true

class String
  alias :contains? :include? # I like contains much better :)
end

class MultipleRunsSameSettingGrapher # should be called MultipleRunsSameSettingGrapher
  attr_reader :dirName
  attr_reader :arrayContainingArraysOfClientsPerRun

  def self.get_log_files_list runName
    glob_string = "../logs/**/#{runName}_*/peer*.log.txt" # ignore  extra parameters..., allows for 'super runs' , too of submitting a 'higher' spec... i.e. run_10 incorporated run_10_1 an drun_10_3-- all in one
    files = Dir.glob(glob_string)
    assert(files.length > 0, "ACK I THINK RUN DID NOT WORK no files found! #{runName} #{glob_string}")
    files
  end

  def initialize(runs, outputName = runs.join('_'), already_created_runs_that_want_to_be_combined = nil)
    assert runs.class == Array && runs[0].class == String
    @runs = runs
    @dirName = MultipleRunsSameSettingGrapher.pictureDirectory + "/single_run_pics/#{outputName[0..100]}"
    @outputNameRequested = outputName
    Dir.mkPath(@dirName)
    @templateName = @dirName + "/"
    @arrayContainingArraysOfClientsPerRun = []
    @graphSmoothFactor = 15 # tenths around itself... this can be rather a slowdown, if I remember correctly, if set too high
    @allClientsInOne = [] # most want
    @spanDuplesPerRunArray = []
    startTimes = []
    endTimes = []
    if already_created_runs_that_want_to_be_combined
      assert already_created_runs_that_want_to_be_combined.class == Array
      assert already_created_runs_that_want_to_be_combined[0].class == MultipleRunsSameSettingGrapher
      @arrayContainingArraysOfClientsPerRun = []
      already_created_runs_that_want_to_be_combined.each{|run| @arrayContainingArraysOfClientsPerRun << run.arrayContainingArraysOfClientsPerRun[0]} # I suppose we could rip out more but this is the main part :)
    else
      for run in runs
        files = MultipleRunsSameSettingGrapher.get_log_files_list run # ignore  extra parameters..., allows for 'super runs' , too of submitting a 'higher' spec... i.e. run_10 incorporated run_10_1 an drun_10_3-- all in one
        thisRunsClientsArray = []
        for filename in files
          client = ClientLogContainerWithStats.new(filename)
          thisRunsClientsArray << client
        end
        @arrayContainingArraysOfClientsPerRun << thisRunsClientsArray
      end
    end
    
    # continue onward...

    for run in @arrayContainingArraysOfClientsPerRun
      startTimesThisRun = []
      endTimesThisRun = []
      for client in run
        @allClientsInOne << client

        filename = client.filename # for logging
        if !client.start
          print "ERROR client has not a start " + filename + " has not a start"
        end
        startTimes << client.start if client.start
        startTimesThisRun << client.start if client.start
        if not client.logFinished
          print "ERROR SEEDO client has not a log end! "  + filename + client.subject.lastLine.to_s + "\n\n\n\n"
        end

        if not client.end
          print "ERROR SEEDO client has not a file downloading end "  + filename + client.subject.lastLine.to_s + "\n\n\n\n"
        else
          endTimes << client.end
          endTimesThisRun << client.end
        end
      end
      startFrame = startTimesThisRun.percentile 10
      endFrame = endTimesThisRun.percentile 80
      @spanDuplesPerRunArray << [startFrame, endFrame]       # unused, I think ltodo get rid of if not using

    end

    if endTimes.length < startTimes.length
      print "ERROR SOME FINISHED NOT!!!\n\n\n"
    end
    print "%d started, %d ended\n" % [startTimes.length, endTimes.length]

  end

  def self.pictureDirectory
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
    allMethods['died'] = 0
    for client in @allClientsInOne
     if client.end
       allMethods[client.endMethod] += 1
     else
       allMethods['died'] += 1
     end
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



  # this one is not restricted
  # but server BPS is
  # and they are graphed in vary parameters, just the percentiles
  # so I would say they are all off, except for server BPS
  # ... I think [?]
  def goTotalThroughPut(filenameOutput)
    raw = filenameOutput + ".raw.txt"
    createTotalThroughPutsReturnPartial(raw, :write_to_file => true, :include_host_bytes => true, :include_peer_received_bytes => true) # not actually partial
    graphTotalThroughPut(raw, filenameOutput)
  end

  def totalThroughPutPointsPartial
    createTotalThroughPutsReturnPartial(:include_host_bytes => true, :include_peer_received_bytes => true).flipIndexValueOfContainedDuples # ltodo take out ending
  end

  def allReceivedPointsPartialP2P
    createTotalThroughPutsReturnPartial(:include_peer_received_bytes => true).flipIndexValueOfContainedDuples
  end

  # these are percentiles into vary parameters [poorly]
  # but not single graphed, currently
  def allServedPointsPartialP2P
    createTotalThroughPutsReturnPartial(:include_peer_send_bytes => true).flipIndexValueOfContainedDuples
  end

  # this is total throughput/p2p served
  # and should probably be combined with server BPS
  # but isn't for some bizarre reason
  # ideally
  # this one would...save it all, so it can recreate single graphs
  # but pass back only the FromHereToHere
  # since that is what vary parameters wants
  # which is the only consumer of data from this one
  # so the grapher instance, above, should be reading from the "ful" "raw" "non fromHeretoHere" and graphing that
  # which it is
  # it must not be saving typically...because..uh...um...it's only run during the huge runs
  # and just hasn't been setup for it yet [nor the others, really]...
  
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
      #
      # except they *do* have the edges currently...
      # 
      pointsWithoutTheEdges += nonpointsWithoutTheEdges.onlyFromHereToHere(0,10000000)#spanDuple[0], spanDuple[1])      
      
    }
    
    
    # I think my goal here was save off/graph all points
    # but if vary parameter requested the data, i would pass it back only the fromHereToHere data
    
    pointsWithoutTheEdges = [pointsWithoutTheEdges].combineSeveralArraysToBucketsWithZeroes @graphSmoothFactor
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
      newBuckets = allReceivedArrays.combineSeveralArraysToBucketsWithZeroes(@graphSmoothFactor)
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
  
  
  # here I pass back partial data but save "all" data
  def createServerBytesPerSecondReturnPartial(rawFilename = @templateName + "server_total" + ".raw.txt")
    partialServedPoints = []
    @arrayContainingArraysOfClientsPerRun.each_with_index { |run, index|
      spanDuple = @spanDuplesPerRunArray[index]
      nonpointsWithoutTheEdges = []
      for client in run
        nonpointsWithoutTheEdges += client.allReceivedHost
      end
      toAdd =  nonpointsWithoutTheEdges.onlyFromHereToHere(spanDuple[0], spanDuple[1])
      partialServedPoints << nonpointsWithoutTheEdges.onlyFromHereToHere(spanDuple[0], spanDuple[1])
    }
    partialServedPoints = partialServedPoints.combineSeveralArraysToBucketsWithZeroes().divideEachValueBy(@arrayContainingArraysOfClientsPerRun.length)

   # now make [recreate] the full thing, without restriction
   # to pass back
   # which is also insanity

    allEntries = []
    # ltodo combine with above loop!
    for client in @allClientsInOne
      allEntries << client.allReceivedHost
    end # ltodo fake server should NOT propagate the size :)
    collapsed = allEntries.collapseMultipleArrays
    newBuckets = [collapsed].combineSeveralArraysToBucketsWithZeroes(@graphSmoothFactor)
    # now add zeroes-- zeroes count this time :)  ltodo should zeroes count for others, perhaps, too?
    newBuckets = newBuckets.divideEachValueBy(@arrayContainingArraysOfClientsPerRun.length) # we should be 'too high' :) this will bring us down to size
    newBucketsCopy = LineWithPointsFile.writeAndReadSingle(rawFilename, "server received by peer points", newBuckets)
    # fails in error ...    assertEqual newBucketsCopy, newBuckets
    partialServedPoints# guess we don't want to flatten here?  
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
    MultipleRunsSameSettingGrapher.graphOpenDHT(raw, filenameOutput)
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
    if allPutsByTime.length == 0; print "ACK! this had better be CSno puts means no p2p impossible!??" end

    if allGetsByTime.length == 0
      print "ack! no gets means no p2p receive action at all recorded"
    end

    toWrite = [["Puts", allPutsByTime.sort], ["Gets", allGetsByTime.sort], ["Removes", allRemovesByTime.sort]]
    a = LineWithPointsFile.new(rawFilename) #ltodo clean
    a.write(toWrite)
    return allPutsByTime, allGetsByTime, allRemovesByTime

  end

  def self.graphOpenDHT(rawFilename, filenameOutput)
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
          print "ERROR ERROR no download time #{use_total_for_all_files} total failed: #{total_failed += 1}!" if $VERBOSE
        end
      rescue => detail
        # unexpected
        print "ERROR client non end" + detail.to_s
      end
    end

    if total_failed > 0
        puts "had failures total #{use_total_for_all_files}: #{total_failed}"
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
    failed_count = 0
    for client in @allClientsInOne
      begin
        value = if use_total_all_files then client.totalDownloadTimeAllFilesDownloaded else client.totalDownloadTime end
        if value
          allTimes.addToKey(value.truncateToDecimal(2), 1)
        else
          print "WARNING no downloadtimes!"  if $VERBOSE
          failed_count += 1
        end
      rescue => detail
        print "ack client no download time!!!ERROR " + detail.to_s # ltodo not allow, or count these and report them...
      end
    end

    if failed_count > 0
        puts " #{failed_count} clients failed--no download time--ignoring them! use total: #{use_total_all_files}"
    else
        puts "all clients succeeded #{@allClientsInOne.length}"
    end

    if allTimes.length == 0
      print "NONE APPEARED TO HAVE FINISHED use_total #{use_total_all_files}\n"
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

class ::Array

  def combineSeveralArraysToBucketsWithZeroes(secondsMod = 1)
    found_something = false
    for subArray in self
        assert subArray.is_a? Array
        # unfortunately it might be [[]] totally empty, like for all p2p traffic on a CS run
    end
    combined = self.combineSeveralArraysToStraightHash # ltodo is this call really necessary?
    return combined.truncate_and_combine_keys(secondsMod).toArrayWithIntermediateZeroesByResolution(secondsMod)
  end

  def combineSeveralArraysToStraightHash
    newBuckets = {}
    for timePointArray in self
      for time, bytes in timePointArray
        newBuckets.addToKey(time, bytes)
      end
    end
    return newBuckets
  end
end

  # ltodo give back to gruff
  def createAllIndividuals
    for client in @allClientsInOne
      client.createIndividual @dirName
      print ".c"
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
    VaryParameter.doStatsSingleRun(@outputNameRequested, [self], @dirName) # our output directory tlodo only calculate them once
    VaryParameter.doStatsSingleRun(@outputNameRequested, [self]) # normal "stats all go here" directory
    Dir.createIndexFile(@dirName)
  end

  def MultipleRunsSameSettingGrapher.doTestRun(runNumber) # incomplete
    templateName = "test/pics/#{runNumber}/test_run_#{runNumber}_"
    a = MultipleRunsSameSettingGrapher.new([runNumber])
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

end # class


class Hash

  # convert a hash with arbitrary key, values
  # like {3.19 => 1600}
  # to be just integer keys
  def truncate_and_combine_keys(seconds_mod)
    new_truncated = {}
    
    for key, value in self
        extra = key.to_i % seconds_mod
        new_truncated.addToKey(key.to_i - extra, value)
    end
    # if we've been conglomming 5seconds worth into each reading
    # that one reading should actually be 1/5th itself, as if it were one second...
    new_truncated_and_divided = {}
    new_truncated.each{|second, large_value|
      new_truncated_and_divided[second] = large_value.to_f/seconds_mod
    }
    new_truncated_and_divided
  end
        
  # this doesn't change the values but just 'spreads' them all out int he new one, with finer granularity 
  # (like having .1.1.1.1.1 instead of just .1 which is...still the same..mostly)
  # howManyTenthsTotal = 10 
  # >> {1.0 => 300}.toTenthsSummedHash(10)
  # => {0.60=>300.0, 0.7=>1000.0...}
  #
  # so this one is taking "raw" hashes
  # and splitting them among 10ths
  #
  # todo replace with truncate_and_combine_keys
  #
  #
  def toTenthsSummedHash(howManyTenthsTotal = 10)


    howManyTenthsTotal = howManyTenthsTotal.to_f
    newBuckets = {}
    for original_time, bytes in self # [time, bytes] arrays
      # each time goes into...the...we'll say 10 10th afore of it.
      bytes /= (howManyTenthsTotal/10)
      1.upto(howManyTenthsTotal)  { |tenth|
        keyTime = (original_time * 10).to_i # truncate to tenth
        keyTime += tenth - howManyTenthsTotal/2 # make it 'balanced in the middle i.e. fill from 2.5 to 3.5 for 3.0
        keyTime = keyTime / 10.0
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
    if(ARGV.include?('--help') || ARGV.include?('-h'))
      puts 'run as runname1 runname2 # all part of the same run--like run12_at1 run12_at1_2, or just the full name run12_at1 but you\'ll get conglom numbers, like a run of 250 will be 500 now and server total speed will be doubled'
      exit
    end

    $doIndividuals = true # create the ASCII individual graphs...
    # instead of "3 runs same setting grapher" it's "one of those 3, by itself"
    a = MultipleRunsSameSettingGrapher.new(ARGV)
    a.doAll
  else
    #RunGrapher.doTestRun(3144)
    #RunGrapher.testMultiples
    #RunGrapher.doTestRun("grundled-200-lab-2")
    #a = MultipleRunsSameSettingGrapher.new(['test2-10-v2_0_0.5', 'test2-10-v2_1_0.5'])
    #a.doAll
    MultipleRunsSameSettingGrapher.testSelf
  end
end
# vltodo run it with 'super fast local' fast server -- first few clients are faster (?) optimize it that way:)
