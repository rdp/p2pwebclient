
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
    puts 'running', command if $VERBOSE
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
