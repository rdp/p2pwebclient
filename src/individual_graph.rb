#!/opt/local/bin/ruby
# ASCII graph for an individual peer's run
require File.dirname(__FILE__) + '/constants.rb'
require File.dirname(__FILE__) + '/individual_graph'
require File.dirname(__FILE__) + '/graphHelpers.rb'
# ltodo from file doesn't work when run on single file...alone...
class TextLines

  # I want to call it with "addPoint(blockNumber, where, whatSymbol)"
  def initialize
    # how about some hashes and duple arrays?
    # allInfo = [(peer) '1' =>
    #               [ [3, 'y'], [3, 'f']...],
    #            (peer) '2' =>
    #               [ [3, 'g'], [4, 'y']...]
    #             ...
    #           ]
    @allBlocks = {} # ltodo suggest 'if it is never accessed throw an error' oooh
  end
  # ltodo make sure CDF's end y at 1.0, and some CDF's end x at 1.0 [ugh] option to createCDF...maybe...maybe an option to 'just pass back' then go it
  # ltodo start at the 'first starting second'...
  # ltodo it's slightly too wide on the left...huh?

  def addPoint(blockNumber, whereSecond, whatSymbol)

    whereSecond = whereSecond.to_i # truncate :)
    # make sure it's in there
    if not @allBlocks.has_key? blockNumber
      @allBlocks[blockNumber] = []
    end

    @allBlocks[blockNumber] << [whereSecond, whatSymbol] # add it to the array

  end

  def getLargestExpanseThatASecondMustCover(second_in_question)
    largest = 1
    # format is block_number => [[second, symbol]]
    for block, all_symbols in @allBlocks
      sum = 0
      for second, symbol in all_symbols
        if second == second_in_question
          sum += symbol.length
        end
      end
      largest = [largest, sum].max # see if this block had the longest second
    end

    largest = [largest, second_in_question.to_s.length + 1].max # accomodate is second_in_question is itself large
    return largest
  end

  def calculateGreatestSecondNumber
    # start them as the first value
    largestSecond = @allBlocks.sort[0][1][0][0] # hmm ltodo move these into when we clculate it... :)have the client save it :)
    leastSecond = @allBlocks.sort[0][1][0][0]
    @allBlocks.each_pair do  |blockNumber, secondSettingsArray |
      for duple in secondSettingsArray
        largestSecond = [largestSecond, duple[0]].max
        leastSecond = [leastSecond, duple[0]].min
      end

    end
    return largestSecond, leastSecond
  end

  def largestPeer
    return @allBlocks.pairWithGreatestKey[0]
  end

  def generate(toThisFile, thisLegendHash, thisExtra = "")
    fileOut = File.new(toThisFile, "w")

    begin
      largestSecond, leastSecond = calculateGreatestSecondNumber
    rescue => detail
      print "ACK NOT MAKING messed up #{toThisFile}!" + detail.to_s + "\n\n\n\n #{detail.backtrace.join("\n")}"
      return
    end
    # for each second, calculate the most at that second..
    mostAtEachSecondSizes = {}
    leastSecond.upto(largestSecond) do |n|
      mostAtEachSecondSizes[n] = getLargestExpanseThatASecondMustCover(n)
    end
    # ltodo on graph parsing  get the listeners, parse them and display errors :)
    largestBlockNumber = @allBlocks.pairWithGreatestKey[0] # ltodo ugly!
    # ltodo are there other things we'd like in the individual graph?
    # ltodo doing graphs with individuals spits out more data...huh?
    blockSpacingLeftSide = [largestBlockNumber.to_s.length, 2].max # 2 for the size of -1 :)
    @allBlocks.pairWithGreatestKey[0].downto(-1) { |n| # highest at top
      if @allBlocks.has_key? n # if has this block -- should!
        duples = @allBlocks[n]
        lineOutput = "% #{blockSpacingLeftSide}d" % n # add the left most block number to each line
        leastSecond.upto(largestSecond) do |secondNumber|
          # scan through, looking for matches...
          stringToPrint = ""
          for duple in duples
            if duple[0] == secondNumber
              stringToPrint += duple[1] # assume a small size!
            end
          end
          formattedString = "% #{mostAtEachSecondSizes[secondNumber]}s" # insert spaces...
          formattedString = formattedString % stringToPrint
          formattedString = formattedString.gsub(' ','-')
          lineOutput += formattedString
        end
      else
        lineOutput = "--blank!--"
      end
      output = "#{lineOutput}:#{n}\n"
      fileOut.write(output)
    }

    # x axis at the bottom
    fileOut.write("% #{blockSpacingLeftSide}s" % "")
    mostAtEachSecondSizes.sort.each { |secondNumber, secondSize|
      output = "% #{secondSize}s" % secondNumber # wow
      fileOut.write(output)
    }
    output = "\n"
    fileOut.write(output)

    # legend :)
    output = "Legend:\n"
    fileOut.write output
    thisLegendHash.each_pair do |key, value|
      output = " #{key} => #{value}\n"
      fileOut.write output

    end

    fileOut.write(thisExtra)
    begin
      fileOut.close
    rescue Errno::EBADF
      print "SEEDO RUBY bug or NFS: bad file descriptor on #{toThisFile}"
    end
    #print "\nwrote individual to #{toThisFile}"

  end


  def TextLines.testSelf
    guineaPig = TextLines.new
    guineaPig.addPoint(0, 0, 'f')
    guineaPig.addPoint(0, 0, 'd')
    guineaPig.addPoint(1, 1, 'g')
    guineaPig.addPoint(2, 9, 'g')
    guineaPig.addPoint(5, 9, 'g')
    guineaPig.addPoint(5, 100, 'g')
    guineaPig.addPoint(0, 105, 'd')
    guineaPig.addPoint(0, 105, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(1, 106, 'd')
    guineaPig.addPoint(5, 107, 'g')
    guineaPig.addPoint(10, 107, 'g')
    legend = {'d' => 'dog', 'c' => 'cat'}
    guineaPig.generate('test/should_look_pretty_individual.txt', legend)
  end

end


class IndividualGraph

  def initialize(singleFileName, subject)
    @filename = singleFileName
    assert File.exists?(singleFileName), "file #{singleFileName} does not exist!"
    if not subject
      @stats = ClientLogContainerWithStats.new(@filename) # ltodo pass in the parser...eh? maybe?
    else
      @stats = subject
    end
    @graph = TextLines.new
    # note we do not load the tokens, in case some other function wants to parse them itself, and feed them to us as leftovers <sniff>
  end

  def loadAll parser
    while token = parser.getNextGraphableToken
      addToken token
    end
  end

  def create(toFilename)
    parser = SingleLogParser.new(@filename) # may not need it, but hey
    #    toFilename += "total_#{@stats.totalDownloadTime}.txt"
    loadAll parser
    generate parser, toFilename
  end

  def generate parser, toFilename, wantOriginalFile = true
    extra = "Bytes from cs origin #{@stats.sumReceivedHost}\n"
    extra += "Bytes from peers #{@stats.sumReceivedPeers}\n"
    extra += " from file #{(Dir.pwd + "/" + @filename).gsub('/','\\''')}\n"
    extra += " from file #{(Dir.pwd + "/" + @filename)}\n"
    extra += "ended at [#{@stats.end}] total time [#{@stats.totalDownloadTime}]\n"
    extra += "Bytes served: #{@stats.sumServed}"
    if wantOriginalFile
      originFile = File.open(@filename, "r")
      extra += originFile.read
      originFile.close
    end
    @graph.generate(toFilename, parser.legendOut, extra)# ltodo this is weird :) have them pass in the legend
  end

  def addToken token
    if token != :nonToken
      blockNumber, second, symbol, description, extra, extra2 = token
      if blockNumber == :nonBlock#symbol == "START" or symbol == "F" or symbol == "END" or symbol == "W" # f dR w dT vltodo more matching
        blockNumber = -1
      end

      if blockNumber
        @graph.addPoint(blockNumber, second, symbol)
      else
        #pp "not adding token", token # ltodo parse the filesize (?)
      end
    end
  end


  def IndividualGraph.testSelf
    IndividualGraph.createWhole('test/individual_graph_test.log.txt', 'test/yo_individual.txt')
    IndividualGraph.createWhole('test/testIndividual2.txt', 'test/yo2_individual.txt')
  end

  def IndividualGraph.createWhole(fromHere, toHere, client = nil)
    singleSubject = IndividualGraph.new(fromHere, client)
    singleSubject.create(toHere) # ltodo combine?
    print "wrote to #{toHere}"
  end

end

if runOrRunDebug? __FILE__
  if ARGV.length > 0
    IndividualGraph.createWhole(ARGV[0], ARGV[0] + ".graph.txt")
    exit
  else
    print "ACK DOING a random example log!"
    IndividualGraph.testSelf
  end
end