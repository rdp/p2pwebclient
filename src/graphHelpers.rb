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

require './client_log_container_with_stats.rb'
require './single_log_parser.rb'

class Hash

   def Hash.testSelf
    intHash = {1 =>2, 3 => 3}
    assertEqual intHash.toArrayWithIntermediateZeroesByResolution(1), [[1, 2], [2,0], [3,3]]

    a = {1.0 => 2, 1.2 => 3}
    # fill in with blanks
    # ltodo fix assertEqual    assertEqual a.toArrayWithIntermediateZeroesByResolution(0.1), [[1.0, 2],[1.1,0],[1.2,3]]

  end

  # converts this array to another array--an exploded one with zeroes if there are gaps between times
  # where [0]'s are timestamps
  #
  def toArrayWithIntermediateZeroesByResolution(stepResolution)
    if self.empty?
      print "ACK empty and you want it to go to an array with zeroes between?"
      return []
    end

    assert stepResolution.is_a? Fixnum

    min = self.min[0] # lowest second
    max = self.max[0] # highest second
    numberOfSteps = (max - min)/stepResolution + 1
    output = []

    numberOfSteps.times {|n|
      where_at = min + (n*stepResolution)
      if self[where_at]
          output << [where_at, self.delete(where_at)]
       else
          output << [where_at, 0]
       end
    }
    output
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
