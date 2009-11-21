# for parsing a single log file
# it news up a SingleLogParser
# then says "give me the next token"
# token being [time, '$'] or what not

class ClientLogContainerWithStats

  def initialize(filename)
    @filename = filename
    @end = nil
    @start_time = Time.now
    if $VERBOSE
      print "Parsing #{filename} \n"
    else
      print '.'
    end
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
    print "done -- took #{Time.now - @start_time}s\n" if $VERBOSE
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
            if $VERBOSE
              print "whoa duplicated START!!! -- ok if you had a CS restart\n" # not sure if you should reset the start time or not--I'd guess not
            else
              print "CSR!"
            end
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
      if $VERBOSE
        print "ERROR no TOTAL END for #{@filename} -- maybe re run graphs when they're all done?"
      else
        print 'a?'
      end
      return nil
    end

    return @total_end - @start
  end

  def totalDownloadTime
    if @end.nil?
      if $VERBOSE
        print "ACK! #{@filename} failed downloading, I think!? That is odd it never actually finished!\n" 
      else
        print 'F'
      end
    end

    if ! @start
      print "ERROR no start for #{@filename} returning -99\n"
      return nil
    end

    if ! @end
      if $VERBOSE
        print "ERROR NO END for #{@filename} -- maybe re run graphs when they're all done?"
      else
        print '!'
      end
      return nil
    end

    return @end - @start
  end

end


if $0 == __FILE__
  require 'constants'
  subj = ClientLogContainerWithStats.new(ARGV[0])
  print subj.end
end
