# ltodo this...generates an extra rsync or something (?)
# ltodo weird naming with the stats---doesn't seem to do them for multiple, at least where we'd like it too...
#
require 'constants'
require 'multiple_runs_same_setting_grapher.rb'
require 'lib/array_on_disk'
require 'forky'

class VaryParameter
  @@Percentiles = [1,25,50,75,99]

  def initialize graphOutputUniquePath, unitsX
    @outputDir = graphOutputUniquePath
    @unitsX = unitsX
    @variedValues = ArrayOnDisk.new # you need this if you want to use fork much...
    @totalBytesReceivedFromPeersAcrossAllRuns = ObjectOnDisk.new 0
    @totalBytesUploadedByServerAcrossAllRuns = ObjectOnDisk.new 0
    @totalBytesServedFromPeersAcrossAllRuns = ObjectOnDisk.new 0
    Dir.mkPath @outputDir # make the whole path, just in case :)
    @arraysOfPercentiles = {}
    for command, internal_file_name, title, x_axis in @@all_stats do
      @arraysOfPercentiles[command] = ArrayOnDisk.new # this will be an array of measurements, like [[0,10,50,70], [5,15,55,75...]]
    end
    File.new(@outputDir + "/number_stats.txt", "w").close # reset it
  end

  def write_string this
    @outputFile = File.new(@outputDir + "/number_stats.txt", "a")
    @outputFile.write this
    @outputFile.close
  end


  def setup_from_preexisting_data(howVaried, runNamesForEachHowVaried, runGrapherObjectsIfAlreadyCreated = nil)
    assert runNamesForEachHowVaried.class == Array and runNamesForEachHowVaried[0].class == Array and howVaried.class == Array
    assertEqual runNamesForEachHowVaried.length, howVaried.length
    assertEqual howVaried.uniq, howVaried, "can't have two of the same values to graph!"

    assert howVaried.length > 0 # that would not be good

    if howVaried.length == 1
      print "WARNING with vary parameter you might want at least two varied settings!"
    end

    @allRuns = []
    howVaried.each_with_index { |howVariedSetting, index|
      [1].forky {
        # create and an add_run_object--wurx for me
        if runGrapherObjectsIfAlreadyCreated 
          raise 'bad class' unless runGrapherObjectsIfAlreadyCreated[index].class == MultipleRunsSameSettingGrapher
          addThis = runGrapherObjectsIfAlreadyCreated[index]
        else
          runNames = runNamesForEachHowVaried[index]
          print "creating new runs (parsing) -- slow\n\n\n #{runNames}--"
          addThis = MultipleRunsSameSettingGrapher.new(runNames) # load it up :)
          [1].forky { addThis.doAll } # why not?
        end
        add_run_object_and_its_setting(addThis, howVaried[index], runNamesForEachHowVaried[index])
      }
    }
    self
  end


  def add_run_object_and_its_setting(run_object, index, sub_run_names)
    @variedValues << index
    processSingleRun run_object, sub_run_names
  end

  def VaryParameter.varyParameterAndRsync(graphOutputUniquePath, unitsX, howVaried, runNamesForEachHowVaried, run_objects_for_how_each_varied_to_avoid_having_to_recompute=nil)
    if howVaried.length <= 1
      print "ack with vary parameter you need at least two settings! not doing any vary graphs, not rsyncing"
      return
    end
    runner = VaryParameter.new(graphOutputUniquePath, unitsX).setup_from_preexisting_data(howVaried, runNamesForEachHowVaried, run_objects_for_how_each_varied_to_avoid_having_to_recompute)
    runner.doGraphs
  end


  def VaryParameter.getRetValuesFromRuns(command, grapherObject)
    print "going #{command}"
    begin
      results = grapherObject.send(command)
    rescue => detail
      print "FAILED #{command} #{detail} #{detail.backtrace}\n"
      return nil
    end
    return results
  end


  def VaryParameter.getDuplesFromClientsAndPercentile(command, grapherObject)
    puts command
    all = VaryParameter.getRetValuesFromRuns(command, grapherObject)
    trueNumbers = []

    if all == nil # the use of flatten is doing this to us...
        print "ack -- returned us nil #{command}"
        return []
    end

    for duple in all
      if duple[0] == nil
        print "ack! -- returned us nothing #{command}" # ltodo prettier
        return []
      end
      trueNumbers << duple[0]
    end
    #    pp "all distinct together as single list (finally) are", trueNumbers.sort, "from", all.sort
    return VaryParameter.calculatePercentiles(trueNumbers, @@Percentiles)
  end
  # rubydoctest: should round, not average
  # >>  VaryParameter.calculatePercentiles([-9, 0, 1, 2], [1, 25, 50, 75, 99])
  # => [-9, 0, 1, 2, 2]
  # >>  a = []
  # >> 100.times{|n| a << n }
  # >> VaryParameter.calculatePercentiles(a, [1, 25, 50, 75, 99])
  # => [1, 25, 50, 75, 99]
  # a = []
  # doesn't raise if you pass it a blank [necessary]
  # >> VaryParameter.calculatePercentiles(a, [1, 25, 50, 75, 99]) # doesn't actually err--problem with rubydoctest?
  # => [0, 0, 0, 0, 0]


  def VaryParameter.calculatePercentiles(thisArray, thesePercentiles)
    thisArray = thisArray.sort

    if thisArray.length < 3
      print "ACK HARD TO CALCULATE PERCENTILES ON -> #{thisArray.inspect} -- using all zeroes...\n"
      return [0]*thesePercentiles.length
    end

    finishedArrays = []
    for percentile in thesePercentiles
      #      if percentile != 50
      index = thisArray.length/100.0*percentile
      # average those two, I guess
      if index != index.to_i
        index = index.round
      end
      index = [index, (thisArray.length - 1)].min # handle the upper edge case
      percentileValue = thisArray[index]

      # ltodo average
      finishedArrays << percentileValue
    end
    return finishedArrays
  end


  def addPercentilesFromRun(command, run)
    incoming = VaryParameter.getDuplesFromClientsAndPercentile(command, run)
    if !incoming
      raise "ack #{command} failed in run #{run}"
    end
    @arraysOfPercentiles[command] << incoming
  end

  def getPercentilesFromRuns(command)
    raise 'not found' unless @arraysOfPercentiles[command]
    @arraysOfPercentiles[command]
  end

  def doSingleGraph(command, short_name, title, unitsY)
    percentiles = getPercentilesFromRuns(command)
    dbg unless percentiles[0] # may want to examine $! here
    return 'failure failure failure' unless percentiles[0]
    if !percentiles[0][0]
      print "arr FAILED #{command}\n\n\n"
      return nil
    end
    graph = PercentileGraph.new(@@Percentiles)
    @variedValues.each_with_index { |value, index|
      graph.nextPoint(value, percentiles[index])
    }
    begin
      File.open(@outputDir + short_name + '.raw.txt', 'w') { |f|
        f.write percentiles.dup.inspect
        f.write @variedValues.inspect
      }
      graph.generate(@outputDir + short_name, title, unitsY, @unitsX)
    rescue NoMethodError => e
      print "ARRRRRR FAILED #{command} or something\n\n\n seedo fix me! #{e}#{e.backtrace.inspect}"
    end
  end

  @@all_stats = [
    ["allServerServedPointsPartial", "server_speed", "Server upload rate", "Server Bytes / S"],
    ["allReceivedPointsPartialP2P", "p2p_received_partial", "Client receive from p2p rate", "Bytes / S"],
    ["allServedPointsPartialP2P", "p2p_served_partial", "Client send p2p rate", "Bytes / S"],
    ["createClientTotalUpload", "client_upload_rate", "Client Upload Sum", "Bytes / Client"],
    ["totalThroughPutPointsPartial", "total_upload_rate", "Total receive rate", "Bytes / S"],
    ["createClientDownloadTimes", "client_download" ,"Download Time" , "(S)" ],
    ["createClientTotalDownloadTimes", "client_download" ,"Download Time (all files)" , "(S)" ],
    ["multipleDHTGets", "dht_get", "DHT Get Times", "(S)" ],
    ["multipleDHTPuts", "dht_Put", "DHT Put Times", "(S)" ],
    ["multipleDHTRemoves", "dht_Remove", "DHT Remove Times", "(S)" ],
    ["createPercentFromClients", "percent_from_clients", "Percent downloaded strictly from clients", "% of File" ]
  ]

  def doGraphs
    for command, internal_file_name, title, x_axis in @@all_stats do
      doSingleGraph(command, internal_file_name, title, x_axis)
    end
    # ltodo calculateAndDoSingleGraphFromRuns("getDeathMethodsAveraged['dR']", "death_method", "Death method", "(%)" )
    # ltodo stuff that are single numbers--graph them!
    do_global_stats
    Dir.createIndexFile(@outputDir) # ltodo add the stats, too
    print 'wrote to (still open)', @outputFile.path, "\n"
  end

  def do_global_stats
    write_string "@totalBytesReceivedFromPeersAcrossAllRuns: #{@totalBytesReceivedFromPeersAcrossAllRuns.dup}
    @totalBytesUploadedByServerAcrossAllRuns = #{@totalBytesUploadedByServerAcrossAllRuns.dup}
    @totalBytesServedFromPeersAcrossAllRuns = #{@totalBytesServedFromPeersAcrossAllRuns.dup}"
  end

  def processSingleRun single_run, sub_run_names
    for command, internal_file_name, title, x_axis in @@all_stats do
      addPercentilesFromRun(command, single_run)
    end
    addNumberStatsForSingleSettingOfVarianceVariable single_run, sub_run_names
  end

  def ppAndFile *multipleArgs
    for arg in multipleArgs
      pp arg
      write_string(arg.to_s + "\n")
    end
  end

  # these are basically the 'single number' stats per run--I think :P
  def addNumberStatsForSingleSettingOfVarianceVariable  run_object , values
    statsGuy = run_object
    # note non use of index to lookup value...
    ppAndFile "-----------", "Doing stats on runs runs just numbers #{values.inspect}"
    ppAndFile "download times %'iles'", VaryParameter.getDuplesFromClientsAndPercentile("createClientDownloadTimes", statsGuy).join(" ")
    ppAndFile "download total times %'iles'", VaryParameter.getDuplesFromClientsAndPercentile("createClientTotalDownloadTimes", statsGuy).join(" ")
    ppAndFile "death methods", statsGuy.getDeathMethodsAveraged.sort.join(" ")

    ppAndFile "server upload [received] distinct seconds [instantaneous server upload per second] %'iles'",
    VaryParameter.getDuplesFromClientsAndPercentile("allServerServedPointsPartial", statsGuy).join(" ")

    ppAndFile " instantaneous tenth of second throughput %'iles'",
    VaryParameter.getDuplesFromClientsAndPercentile("totalThroughPutPointsPartial", statsGuy).join(" ")

    ppAndFile "upload bytes %'iles'", VaryParameter.getDuplesFromClientsAndPercentile("createClientTotalUpload", statsGuy).join(" ")
    ppAndFile "dht gets", VaryParameter.getDuplesFromClientsAndPercentile("multipleDHTGets", statsGuy).join(" ")
    ppAndFile "dht puts", VaryParameter.getDuplesFromClientsAndPercentile("multipleDHTPuts", statsGuy).join(" ")
    ppAndFile "dht removes", VaryParameter.getDuplesFromClientsAndPercentile("multipleDHTRemoves", statsGuy).join(" ")
    ppAndFile "percentiles of percent received from just peers (not origin)", VaryParameter.getDuplesFromClientsAndPercentile(
    "createPercentFromClients", statsGuy).join(" ") # ltodo graphs for percent dT

    ppAndFile "client upload sum percentiles:", VaryParameter.getDuplesFromClientsAndPercentile("createClientTotalUpload", statsGuy).join(" ")
    ppAndFile " :totalBytesReceivedFromPeersAcrossAllRuns #{statsGuy.totalBytesReceivedFromPeersAcrossAllRuns}, :totalBytesUploadedByServerAcrossAllRuns #{statsGuy.totalBytesUploadedByServerAcrossAllRuns} :totalBytesServedFromPeersAcrossAllRuns #{statsGuy.totalBytesServedFromPeersAcrossAllRuns}"
    @totalBytesReceivedFromPeersAcrossAllRuns.plus_equals(statsGuy.totalBytesReceivedFromPeersAcrossAllRuns)
    @totalBytesUploadedByServerAcrossAllRuns.plus_equals(statsGuy.totalBytesUploadedByServerAcrossAllRuns)
    @totalBytesServedFromPeersAcrossAllRuns.plus_equals(statsGuy.totalBytesServedFromPeersAcrossAllRuns)
    #ltodo note how many opendht's never came back
    #ltodo say how many did not make it, too...
    print "wrote stats to #{@outputFile.path}\n"
  end

  def VaryParameter.testSelf()
    # ?? @outputFile.close # avoid bug in fork on 1.9.1...
    runs = ['10_seconds','two_minutes', '10_seconds_2']
    vary = VaryParameter.new(MultipleRunsSameSettingGrapher.pictureDirectory + '/vary_parameter/' + "../test_vary/test_vary_output_dir", "time run ran", [10,120],[['10_seconds','10_seconds_2'],['two_minutes']])
    vary.numberStatsForEachSettingOfVarianceVariable
    #vary.doAllAndRsync
    vary = VaryParameter.new(MultipleRunsSameSettingGrapher.pictureDirectory + '/vary_parameter/' + "test/testvary", "my fake x", [0.5], [['testVary2_run0_at0.5', 'testVary2_run1_at0.5']]) # no graphs!
    vary.doAllAndRsync
    VaryParameter.doStatsSingleRun(['test2-10-v2_0_0.5', 'test2-10-v2_1_0.5'])
    VaryParameter.varyParameterAndRsync(MultipleRunsSameSettingGrapher.pictureDirectory + '/vary_parameter/' + "test_vary_parameter_graphs_default", 'Server Bytes/Peer/S', [1, 5, 10], [['1_1'], ['5_1', '5_2'], ['10_1', '10_2']]) # visual inspect, I suppose
  end

  # runNames can be 'run12_at1' or ['run12_at1', 'run12_at1_take2']
  def VaryParameter.doStatsSingleRun(runNames, existingGraphs = nil, outputDirectoryForStats = MultipleRunsSameSettingGrapher.pictureDirectory)
    print "doing #{runNames} stats single run, as all one combined stats, I think => #{outputDirectoryForStats}/single_shot_stats"
    runNames = Array(runNames)
    assert existingGraphs.class == Array if existingGraphs
    vary = VaryParameter.new(outputDirectoryForStats + "/single_shot_stats/" + runNames.join('_'), "fake x unit").setup_from_preexisting_data([0], [runNames], existingGraphs)
  end

end
# doctest: should run some tests together, create some graphs
#
# >> File.delete "../#{Socket.gethostname}/vary_parameter/vary_parameter/vr_vary_parameter_test7_@@dT_fromStart_1by_AndMajorTimes_1_times_0.0666666666666667s__0s_100000B_255000BPS_125000s_1s_2.0s_100000B//number_stats.txt" rescue nil
#
# >> File.delete  "../#{Socket.gethostname}/vary_parameter/vary_parameter/vr_vary_parameter_test7_@@dT_fromStart_1by_AndMajorTimes_1_times_0.0666666666666667s__0s_100000B_255000BPS_125000s_1s_2.0s_100000B/dht_Remove_PercentileLine.gif" rescue nil
#
# >> VaryParameter.varyParameterAndRsync(MultipleRunsSameSettingGrapher.pictureDirectory + '/vary_parameter/vr_vary_parameter_test7_@@dT_fromStart_1by_AndMajorTimes_1_times_0.0666666666666667s__0s_100000B_255000BPS_125000s_1s_2.0s_100000B', 'T (seconds) -- smalltest',[1.0, 3.0],[["vary_parameter_test7_@@dT_at1_run1_of_2_major_1_of_2", "vary_parameter_test7_@@dT_at1_run2_of_2_major_1_of_2"], ["vary_parameter_test7_@@dT_at3_run1_of_2_major_2_of_2", "vary_parameter_test7_@@dT_at3_run2_of_2_major_2_of_2"]])
#
# # does its thing
#
#>> File.exist? "../#{Socket.gethostname}/vary_parameter/vary_parameter/vr_vary_parameter_test7_@@dT_fromStart_1by_AndMajorTimes_1_times_0.0666666666666667s__0s_100000B_255000BPS_125000s_1s_2.0s_100000B//number_stats.txt"
#=> true
#>> File.exist? "../#{Socket.gethostname}/vary_parameter/vary_parameter/vr_vary_parameter_test7_@@dT_fromStart_1by_AndMajorTimes_1_times_0.0666666666666667s__0s_100000B_255000BPS_125000s_1s_2.0s_100000B/dht_Remove_PercentileLine.gif"
#=> true


if runOrRunDebug? __FILE__
  require 'singleMultipleGraphs.rb' # should work -- there may be some dependency problem in there
  if ARGV.length > 0
    print "doing single stats on #{ARGV}"
    VaryParameter.doStatsSingleRun(ARGV)
  else
    raise 'tell me what to run on!'
  end
end
