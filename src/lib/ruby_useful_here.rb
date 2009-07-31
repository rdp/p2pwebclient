#Roger Pack
# note: probably not useful to ANYONE :)

require 'pp'
require 'thread'
# to use  require "useful_ruby_utilities"
# ltodo move in to real
#require 'resolv-replace'
#
#
def dbg
begin
  require 'rubygems'
  require 'ruby-debug'
  debugger
rescue LoadError
end
end
class Object
 # mostly means non-nil
 def is_text?
  if self.respond_to? :blank?
    return !self.blank?
  else
    return self.to_s.length > 0
  end
 end

 def alias2 hash
	for key, value in hash
		alias_method key, value
	end
 end
end

if RUBY_VERSION < '1.9'
  require 'tempfile'
  class Tempfile
    def make_tmpname(basename, n)
      case basename
      when Array
        prefix, suffix = *basename
      else
        prefix, suffix = basename, ''
      end

      t = Time.now.strftime("%Y%m%d")
      path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}-#{n}#{suffix}"
    end
  end
end




def parseArgsToRubyObjectsArray(args) # incoming args as strings ltodo choose a class :)
  outputArray = []
  for setItToThis in args
    if setItToThis =~ /^[0-9]+\.[0-9]+$/
      setItToThis = setItToThis.to_f
    elsif setItToThis == "false"
      setItToThis = false
    elsif setItToThis == "true"
      setItToThis = "true"
    elsif setItToThis =~ /^[0-9]+$/
      setItToThis = setItToThis.to_i
    else
      assert setItToThis.class == String # it's a string :)
    end
    outputArray << setItToThis
  end
  return outputArray
end

def on_windows?
  RUBY_PLATFORM =~ /djgpp|(cyg|ms|bcc)win|mingw/
end

class AssertionFailure < StandardError # from http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/41639
end

class GenerateBackTrace < StandardError
end

def goGetFile(urlToGet, whereItGoes = nil)
  wgetCommand = "wget #{urlToGet}"
  if whereItGoes
    wgetCommand += " -O #{whereItGoes}"
  end
  # ltodo double check this, see if wget exists, etc...
  if system(wgetCommand)
    return
  else
    require 'open-uri'
    # ltodo guard this
    writeOut = open(whereItGoes, "wb")
    writeOut.write(open(urlToGet).read)
    writeOut.close
    print "ACK NO WGET!"
    #puts "downloaded" + urlToGet + "\n"
  end
  
end

def isGoodExecutableFile?(thisFileName)
  if File.executable_real? thisFileName
    return true
  end
  begin
    a = IO.popen(thisFileName, "w+")
    returnVal = true
    # if that cleared then the exec worked
    a.close
    rescue => details
    returnVal = false
  end
  return returnVal # ltodo there's some bug with this
end


class String

  def blank?
   self.length == 0
  end

  def contains? thisString
    return self.index(thisString) != nil
  end
  
  def escape
    return self.gsub('$', '\$')
  end
  
  def sanitize
    self.gsub(/[`\.?*\/\\|<>!&;:"'~@#\$%\^\(\)]/, '_')
  end
  def sanitize!
    self.gsub!(/[`\.?*\/\\|<>!&;:"'~@#\$%\^\(\)]/, '_')
  end
  
  def shiftOutputAndResulting number
    if number.class == Float
      number = number.ceil
      #   print "warning you passed me a float? huh?\n" ltodo debug
    end
    assert number != 0
    output = self[0..(number -1)]
    rest = self[number..-1]
    if rest != nil and rest.length == 0
      rest = nil
    end
    return output, rest # ltodo better funcs
    
  end
end


class Object
  def assert(bool, message = '')
    if not bool
      message = "ERROR assertion failed!" + message
      print message
      begin
        raise AssertionFailure.new(message)
        rescue AssertionFailure => a
        print a.backtrace[1..-1].join("...")
        print "\n"
        raise
      end
    end
  end

  def in? array
   array.include?(self)
  end
end

def assertEqual(a, b, errorString = "")
  if a != b
    message = "ERROR NOT EQUAL: [" + a.to_s + "] != [" + b.to_s + "] #{errorString}\n"
    print message
    pp a, "!=", b
    raise AssertionFailure.new(message)
  end
end

def debugMe(scriptName) # __FILE__ -- old
  if (defined? $PROGRAM_NAME and ($PROGRAM_NAME.index("rdebug") or $PROGRAM_NAME.index("prof")) and ARGV[-1] == scriptName)     
    ARGV.pop
    print "running in debug " + scriptName + "\n"
    return true
  else
    return false
  end
end

def runOrRunDebug?(currentFile) # __FILE__ #ltodo replace with this :) this is the latest and greatest
  if $0 == currentFile
    return true
  end

  if File.expand_path($0) == File.expand_path(currentFile) # case ruby-prof --replace-prog-name
        return true
  end

  
  if (defined? $PROGRAM_NAME and ($PROGRAM_NAME.index("rdebug") or $PROGRAM_NAME.index("prof")))
    comparator = currentFile[2..-4] # strip off the opening ./, ending .rb :)
    if (ARGV[-1] == comparator)
      ARGV.pop
      print "running in debug/prof: " + currentFile + "\n"
      return true
    end
  end
end

class File
  class << self
    def fileSize(filename) 
      return File.stat(filename).size
    end
  end
end

class Dir
  class << self
    
    def createIndexFile(dirName, globIn = '*.{png,gif,jpg}')
      File.open(dirName + "/ind.html", "w") do |indexFile|
        for file in Dir.glob(dirName + '/'  + globIn) do indexFile.write("<img src=#{file.split('/')[-1]}>") end
        indexFile.write("<br>Index for #{dirName}, #{globIn}<br><a href='.'>see all</a>")
      end
    end
    
    def stripEndingPathAspectStartingWithNoEndingSlashReturningAnEndingSlash thisString
      assert thisString[-1..-1] != '/'
      legitParts = thisString.split('/')[0..-2]
      allTogether = legitParts.join('/') # ooh the irony
      allTogether += '/' if legitParts.length > 0 # allow for small guys to remain small, like '/b'
      return allTogether
    end
    
    
    def mkPath path
      # ltodo File.directory? "good_dir/bad_dir" -> True
      oldDir = Dir.pwd
      finalDir = "/"
      for part in path.split("/")
        if part != ""
          finalDir = finalDir + part + "/"
          if not File.directory? part then 
            Dir.mkdir part
          end
          Dir.chdir(part) # unfortunately necessary
        else
          # assume it was beginning. if so chdir / so we can make it the right way :)
          Dir.chdir("/")
        end
      end
      Dir.chdir(oldDir)
    end
    
  end
end

require 'timeout'
require 'socket' # gotta override a previously instantiated socket! eck
class Numeric
    def ord; self; end unless RUBY_VERSION[0..2] == '1.9' # helper for 1.8/1.9
end

class Socket
  class << self
    def get_ip hostName
      begin
       ipInt = gethostbyname(hostName)[3]
        return "%d.%d.%d.%d" % [ipInt[0].ord, ipInt[1].ord, ipInt[2].ord, ipInt[3].ord]
      rescue SocketError # bizarre, but happens
	return ''
      end
    end
    
    def get_host_ip
      begin
	ip = Socket.getaddrinfo(Socket.gethostname, nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM, nil, Socket::AI_CANONNAME).select{|type| type[0] == 'AF_INET'}[0][3] # ltodo hmm we don't want it to do the reverse lookups!
        raise if ip.blank?
        return ip
      rescue => e
	get_ip(Socket.gethostname) # less accurate or something, I guess
      end
    end
    
  end
end


class TCPSocketConnectionAware < TCPSocket
  
  def initialize *args
    super *args
    @amPastHeader = false # ltodo put this in http?
  end
  attr_accessor :amPastHeader, :currentTransmissionSize, :totalFileSize
  def amPastHeader? *args
    return self.amPastHeader(*args)
  end
  def nukeHeaderAndSetBoolAndSizeIfThere fromThis
    amPastHeader, newData, currentTransmissionSize, totalFileSize = TCPSocketConnectionAware.parseReceiveHeader fromThis
    @amPastHeader = true if amPastHeader
    @currentTransmissionSize = currentTransmissionSize if currentTransmissionSize
    @totalFileSize = totalFileSize if totalFileSize
    return newData
  end
  
  def TCPSocketConnectionAware.parseReceiveHeader fromThis
    answerArray = fromThis.scan(@@contentLengthRegEx)
    if answerArray.length > 0
      currentTransmissionSize = answerArray[0][0].to_i # ltodo tell ruby to do lazy eval's for this.
    end
    answerArray = fromThis.scan(@@contentRangeRegToFileSizeEx)
    if answerArray.length > 0
      totalFileSize  = answerArray[0][0].to_i
    end
    
    locationOfSplit = fromThis.index("\r\n\r\n") # an ending mark
    if locationOfSplit != nil
      amPastHeader = true
      returnable = fromThis[locationOfSplit + 4..-1]
    else
      print "very odd! -- [#{fromThis}] must be in the header still!"
      amPastHeader = false
      returnable = ""
    end
    return amPastHeader, returnable, currentTransmissionSize, totalFileSize
  end
  class << self
    @@contentRangeRegToFileSizeEx = /Content-Range: bytes .*\/(\d+)/
    @@contentLengthRegEx =  /Content-Length\: (\d+)/
    
    def createReturnHeader(startByte = nil, endByte= nil, fileSize= nil) # ltodo move fileSize to beginning ltodo rename 'createPartialByteReturnHeader
      assert endByte >= startByte if endByte
      assert !endByte unless startByte
      outString = ""
      if endByte 
     	 outString << "HTTP/1.1 206 Partial Content\r\n"
     	 outString << "Content-Length: #{endByte - startByte + 1}\r\n"
      else
	outString << "HTTP/1.1 200 OK\r\n"
      end

      outString << "Server:p2p_webclient\r\n"
      outString  << "Content-Range: bytes #{startByte}-#{endByte}#{fileSize ? '/' + fileSize.to_s: ''}\r\n" if startByte  # ltodo could add connection: close
	outString << "Content-Type: text/plain\r\n"
      outString << "\r\n"
      return outString
    end
   
    # doctest: splitUrl
    # >> splitUrl('http://betterlogic.com')
    # => ['', 'betterlogic.com', 80]
    # >> splitUrl('http://betterlogic.com/')
    # => ['/', 'betterlogic.com', 80] 

    def splitUrl(fullUrl)
      answerArray = fullUrl.scan(/http:\/\/([^\/]+)(\/\S*)*/i)
      if answerArray.length == 0
        print "ERROR uh oh #{fullUrl} doesn't seem to be a full url like http://www.example.com/\n"
        return
      end
      pageOnly = answerArray[0][1] || '' # cover case of 
      hostAndIP = answerArray[0][0]
      hostToGetFrom = hostAndIP.split(":")[0]
      ipPortToGetFrom = (hostAndIP.split(":")[1] || '80').to_i 
      return pageOnly, hostToGetFrom, ipPortToGetFrom
    end
    
    def  createHTTPRequest(pageTitle, host, ip=80, byteStart = nil, byteEnd = nil)
      return createHTTPRequestInternal(pageTitle, host, ip, byteStart, byteEnd, "GET")
    end
    
    def createHTTPHeadRequest(pageTitle, host, ip=80)
      return createHTTPRequestInternal(pageTitle, host, ip, nil, nil, "HEAD")
    end
    
    def createHTTPRequestInternal(pageTitle, host, ip, byteStart, byteEnd, getOrHead = "GET") # ltodo not use -1
      assert byteEnd >= byteStart, "whoa cannot request head less than tail" if byteEnd and byteStart
      assert pageTitle
      original = getOrHead + " " + pageTitle + " HTTP/1.1\r\nHost: #{host}:#{ip}\r\nUser-Agent: Roger_Pack_Thesis\r\n"
      # let's see...add the start byte stuff unless it is nil or zero and byteEnd is nil [0 - nil is everything, so just pass back the full request]
      if byteStart and not (byteStart == 0 and not byteEnd)
        original += "Range: bytes=%d-" % byteStart
        if byteEnd
          original += byteEnd.to_i.to_s
        end
        original += "\r\n"
      end
      original += "\r\n\r\n"
      return original
    end # ltodo an interesting modification would be to 'resume' on the first block, as the default...hmm...kind of like picking up a new peer...
    def parseHTTPRequest(request)
      httpRequestRE = /(GET|HEAD) (?:http:\/\/[^\/]+)?(\/?\S+) HTTP\/1.[10]\r\n.*Host: ?([^:\r]+)(?::(\d*))?\r\n.*/m # note optional (in my opinion) space after Host: , and optional port. HTTP/1.0 for wget, which is odd
      answers = httpRequestRE.match(request)
      file = host = port = start = endy = nil
      if answers 
        requestType = answers[1]
        file = answers[2]
        host = answers[3]
        port = (answers[4] || '80').to_i
        start = nil
        endy = nil
      end
      
      httpRequestRE = /.*\r\nRange: bytes=(\d+)-(\d+)?/
      answers = httpRequestRE.match(request)
      if answers # ltodo test case straight download from a peer of size 100, block size 33
        start = answers[1].to_i
        if answers[2] # if it's nil, then don't do ".to_i" on it. heh.
          endy = answers[2].to_i
          assert endy >= start # note: can be equal, which means 'serve one byte'
        else
          endy = nil
        end
      end
      fullUrl = "http://#{host}:#{port}#{file}" 
      return file, host, port, start, endy, requestType, fullUrl
    end
    
    def testSelf
      a = TCPSocketConnectionAware.createHTTPRequest("file", "host", 81, 12, 13)
      file, host, port, start, endy, type, fullUrl = TCPSocketConnectionAware.parseHTTPRequest(a)
      assertEqual [file, host, port, start, endy, type], ["file", "host", 81, 12, 13, "GET"]
      
      b = TCPSocketConnectionAware.createHTTPHeadRequest("file", "host", 81) # size last
      file, host, port, start, endy, type, fullUrl =  TCPSocketConnectionAware.parseHTTPRequest(b)
      assertEqual [file, host, port, start, endy, type], ["file", "host", 81, nil, nil, "HEAD"]
      
      a = TCPServer.new(20002)     
      b = TCPSocketConnectionAware.new('127.0.0.1', 20002)
      a_socket = a.accept
      assert !b.amPastHeader
      req = TCPSocketConnectionAware.createHTTPRequest("file", "host", 81, 12, 13)# ltodo put in a star if there is no ending number!
      b.write req
      received =  a_socket.recv(1024)
      assertEqual received, req
      header = TCPSocketConnectionAware.createReturnHeader(12,13,1001) 
      a_socket.write header
      
      headerBack = b.recv(1024)
      b.nukeHeaderAndSetBoolAndSizeIfThere headerBack
      assert b.amPastHeader
      assertEqual b.currentTransmissionSize, 2
      assertEqual b.totalFileSize, 1001
      
      # same thing, but this time with some extraneous data
      c = TCPSocketConnectionAware.new('127.0.0.1',  20002) # ltodo tell ruby that ,'s aren't necessary TCPSocket.new 'localhost' 2000
      # ltodo note that I kind of want to and could replace the internet with a constantly on, anywhere accessible web
      c_server = a.accept
      addition = "some stuff"
      c_server.write TCPSocketConnectionAware.createReturnHeader(13,14,1001) + addition
      received = c.recv(1024)
      assert !c.amPastHeader
      received2 = c.nukeHeaderAndSetBoolAndSizeIfThere received
      assert c.amPastHeader
      assert c.currentTransmissionSize == 2
      assert c.totalFileSize == 1001
      assertEqual received2, addition
    end
  end # static
end

class Object
  
  def methodLookup(methodName)
    classname = self.class
    
    if classname == "Class" # then methodLookup is being called on a class itself, ala "String.methodLookup(x)" instead of "stringInstance.methodLookup(x)"
      classname = self.name
    end
    result  = system("ri.bat \"%s.%s\" --no-pager" % [classname, methodName]) # only works in windows, here
    if not result
      result  = system("ri \"%s.%s\" --no-pager" % [classname, methodName]) # may work better in linux
    end
    return result
  end
  
end # Object

def writeToFile(a)
  return File.new(a, "w")
end

def readFromFile(b)
  return File.new(b, "r")
end

class Fixnum
  def asIfChar
    return "%c" % self
  end
  def minutesAsSeconds
    return self*60
  end
  def hoursAsSeconds
    return self*60*60
  end
  
end

# and its opposite--kind of -- a very broken string to ascii
class String
  def firstCharToAscii
    return ("%d" % self[0]).to_i
  end
  
  def firstCharToBinary
    return  "%b" % firstCharToAscii()
  end
  
  def stripEnding(char)
    if self[-1..-1] == char
      return self[0..-2]
    else
      return self
    end
  end
  def contains? subString
    return self.index(subString)
  end
  
end

class Hash
  
  def divideValuesBy(this)
    this = this.to_f
    output = {}
    self.each_pair { |key, value|
      output[key] = self[key] / this
    }
    return output
    
  end
  
  def multiplyKeysBy(this)
    output = {}
    self.each_key { |key|
      output[key * this] = self[key]
    }
    return output
  end
  
  def keysToInts
    output = {}
    self.each_key { |key|
      output[key.to_i] = self[key]
      
    }
    return output
    
  end
  
  def sumValues
    sum = nil
    self.each_key { |key|
      if not sum.nil?
        sum += self[key]
      else
        sum = self[key] # keep this non class specific :)
      end
      
    }
    return sum
  end
  
  def addToKey(key, addThis)
    if self.has_key? key
      self[key] += addThis
    else
      self[key] = addThis
    end
  end
  
  def keyValueOrZero key
    if self.has_key? key
      return self[key]
    else
      return 0
    end
  end
  
  
  def pairWithGreatestKey # same as max but doesn't err... ltodo report to ruby!
    greatestKeyPair = nil
    self.each_pair do |key, value|
      if not greatestKeyPair or key > greatestKeyPair[0] # ltodo more fast! submit to ruby!
        greatestKeyPair = [key, value] # to be able to pass them both out
      end
    end
    return greatestKeyPair
  end
  
  def greatestValue
    
    greatestValue = nil
    self.each_pair do |key, value|
      if greatestValue == nil or value > greatestValue[1] # ltodo more fast (?)!
        greatestValue = [key, value]
      end
    end
    return greatestValue
  end
  
  def ifOrderedSumOfValuesUpToAndIncludingKey(maxKey)
    sum = 0
    # self.sort is an array of pairs [[key, value], [key, value]...]
    for key, value in self.sort do 
      if key > maxKey
        break
      end
      sum += value
    end
    return sum
  end
end


class TCPsocket
  
  def writeReliable(stuffIn)
    amountWrote = write(stuffIn)
    assert(amountWrote == stuffIn.length, "ack a socket right (roger) failed! fix!")
    flush # I have no idea if this does anything
    # rest seems unnecessary
    #  totalToSend = stuffIn.length
    #  totalSent = 0
    #  while totalSent < totalToSend do
    #      if totalSent > 0
    #          print "writeReliable looped!!!!i once you see this once then mark it as useful, comment out"
    #      end
    #      received = write(stuffIn)
    #      stuffIn = stuffIn[received..10000000] # ltodo find a better way :)
    #      totalSent += received
    #  end# ltodo test -- appears unnecessary!
    #  flush
    return amountWrote
  end
end

# code for exception handling
#    begin
#      go(bm)
#   rescue  => detail
#     print detail.backtrace.join("\n")
#   end

# code for threading
# return Thread.new(bm) { |bm|

#    begin
#      startClient(fullUrl, bm)
#   rescue  => detail
#     print detail.backtrace.join("\n")
#   end
# }
#
# return Thread.new(bm) { |bm|
#      startClient(fullUrl, bm)
# }


class Float
  
  def truncateToDecimal(decimal)
    return ("%.0#{decimal}f" % self).to_f
  end
end # class
class Array
  def cullDeadThreadsInArray # use array = array.cullDeadThreadsInArray
    out = []
    for thread in self
      if thread.alive?
        out << thread
      else
        # it is dead, let it die
      end
    end
    return out 
    
  end
  
  def joinOnAllThreadsInArrayDeletingWhenDead
    while not self.empty?
      waitForThisThread = self[0]
      assert waitForThisThread.class == Thread
      waitForThisThread.join # make sure it dies first, then we shift it off
      self.shift
    end
  end
  
  def collapsePointsToIntegers
    return toSummedByIntegerHash.sort
  end
  
  def toSummedByIntegerHash # ltodo rename sum
    finalArray = {}
    self.each { |pointDuple|
      finalArray.addToKey(pointDuple[0].to_i, pointDuple[1])
    }
    return finalArray
  end
  
  def dupleArrayToSummedHash
    finalArray = {}
    self.each { |pointDuple|
      finalArray.addToKey(pointDuple[0], pointDuple[1])
    }
    return finalArray
    
  end
  
  def average
    sum = 0
    self.each { |entry|
      sum += entry
    }
    return sum / self.length
  end
  
  
  
  # from http://snippets.dzone.com/posts/show/898
  # Chooses a random array element from the receiver based on the weights
  # provided. If _weights_ is nil, then each element is weighed equally.
  # 
  #   [1,2,3].random          #=> 2
  #   [1,2,3].random          #=> 1
  #   [1,2,3].random          #=> 3
  #
  # If _weights_ is an array, then each element of the receiver gets its
  # weight from the corresponding element of _weights_. Notice that it
  # favors the element with the highest weight.
  #
  #   [1,2,3].random([1,4,1]) #=> 2
  #   [1,2,3].random([1,4,1]) #=> 1
  #   [1,2,3].random([1,4,1]) #=> 2
  #   [1,2,3].random([1,4,1]) #=> 2
  #   [1,2,3].random([1,4,1]) #=> 3
  #
  # If _weights_ is a symbol, the weight array is constructed by calling
  # the appropriate method on each array element in turn. Notice that
  # it favors the longer word when using :length.
  #
  #   ['dog', 'cat', 'hippopotamus'].random(:length) #=> "hippopotamus"
  #   ['dog', 'cat', 'hippopotamus'].random(:length) #=> "dog"
  #   ['dog', 'cat', 'hippopotamus'].random(:length) #=> "hippopotamus"
  #   ['dog', 'cat', 'hippopotamus'].random(:length) #=> "hippopotamus"
  #   ['dog', 'cat', 'hippopotamus'].random(:length) #=> "cat"
  
  def randomItem
    return self[rand(self.length)] # zero based, so this works math-wise...
  end
  
  def randomItemIntense(weights=nil)
    return random(map {|n| n.send(weights)}) if weights.is_a? Symbol
    
    weights ||= Array.new(length, 1.0)
    total = weights.inject(0.0) {|t,w| t+w}
    point = rand * total
    
    zip(weights).each do |n,w|
      return n if w >= point
      point -= w
    end
  end
  
  # Generates a permutation of the receiver based on _weights_ as in
  # Array#random. Notice that it favors the element with the highest
  # weight.
  #
  #   [1,2,3].randomize           #=> [2,1,3]
  #   [1,2,3].randomize           #=> [1,3,2]
  #   [1,2,3].randomize([1,4,1])  #=> [2,1,3]
  #   [1,2,3].randomize([1,4,1])  #=> [2,3,1]
  #   [1,2,3].randomize([1,4,1])  #=> [1,2,3]
  #   [1,2,3].randomize([1,4,1])  #=> [2,3,1]
  #   [1,2,3].randomize([1,4,1])  #=> [3,2,1]
  #   [1,2,3].randomize([1,4,1])  #=> [2,1,3]
  def randomizedVersionIntense(weights=nil)
    return randomize(map {|n| n.send(weights)}) if weights.is_a? Symbol
    
    weights = weights.nil? ? Array.new(length, 1.0) : weights.dup
    
    # pick out elements until there are none left
    list, result = self.dup, []
    until list.empty?
      # pick an element
      result << list.randomItemIntense(weights)
      # remove the element from the temporary list and its weight
      weights.delete_at(list.index(result.last))
      list.delete result.last
    end
    
    result
  end
  
  def eachInRandomOrderWithIndex
    arrayOfNumbersRepresentingUnchosenLocations = (0..(self.length - 1)).to_a
    while arrayOfNumbersRepresentingUnchosenLocations.length > 0
      indexIntoArrayOfUnchosenNumbers = rand(arrayOfNumbersRepresentingUnchosenLocations.length) # rand  index 
      newRandomNumber = arrayOfNumbersRepresentingUnchosenLocations.slice!(indexIntoArrayOfUnchosenNumbers, 1)[0] # slice it out
      yield self[newRandomNumber], newRandomNumber
    end
  end
  
  def randomizedVersion
    output = []
    self.eachInRandomOrderWithIndex { |member, index| 
      output << member
    }
    return output
  end
end

def startThreadsThenJoin array, join = true
  assert block_given?
  allThreads = []
  for element in array
    allThreads << Thread.new(element) { yield(element) }
  end
  allThreads.joinOnAllThreadsInArrayDeletingWhenDead if join
  allThreads
end

class GiveUp < StandardError
end
class NeverThrown < StandardError
end
class ThreadSuccessException < StandardError
end
class ThreadSuccessException < StandardError
end
class ContinueOnward < StandardError
end
# note that you can have it end when X number finish(total) or, earlier, if the doneExceptionIfThrown is raised (looks like you just raise it 'normally' and it works)...not this: => on the parent Thread -- to get the parentThread precede a call to this with parentThread = Thread.current
def threadRaceInjectsGiveUp(array, totalToAllowToFinish = 1, interruptThreads = true, doneExceptionIfThrown = NeverThrown, joinOnAll = true, conkOutIfOneReturnsSuccess = false, killInsteadOfRaise = false, raiseThisToInterruptThreads = GiveUp, &blocky) # pass in a variable for that exception if you want to have it end arbitrarily at some point
  # this assumes they will propagate some other thing of their own, and use ensure to clean selves up
  stillHereMutex = Mutex.new # ltodo don't need a mutex, really...a boolean or something :)
  # LTODO: PUBLISH THIS. LOL.
  begin
    if !array or array.length == 0
      print "ack!"
      return nil
    end
    if doneExceptionIfThrown != NeverThrown
      if interruptThreads == false
        assert joinOnAll != true, "you don't wwant to join on them if they all keep going, though one can finish early"
      end
    end
    
    totalThreadsFinished = 0
    raiseMutex = Mutex.new
    thrown = false
    threads = []
    assert block_given?
    totalToAllowToFinish = array.length if !totalToAllowToFinish
    totalToAllowToFinish = [totalToAllowToFinish, array.length].min # not loop forever if they give us too high a number
    returnThis = nil
    stillHereMutex.synchronize {
      for arg in array
        threads << Thread.new(Thread.current, arg)  { | parentThread, argIn| 
          begin
            shouldThrow = false
            returned = nil
            begin
              returned = blocky.call(argIn)
              if returned and conkOutIfOneReturnsSuccess
                raise ThreadSuccessException, "we have a winner"
              end
              rescue doneExceptionIfThrown, ThreadSuccessException => detail # rescue it from things that we ourselves would raise into it, or it could raise a 'ThreadSuccessException as a message to us that the entire thing is done'
                raiseMutex.synchronize {
                  if not thrown # two could want to throw, from a 'done exceptio nbeing thrown twice--two simultaneous sucesses'
                    shouldThrow = true
                    thrown = true
                    if detail.class == ThreadSuccessException
                      returnThis = returned
                    end
                  else
                    print "odd to have raised the done exception when already done somehow--except that it's possible with simultaneous successes #{argIn} #{stillHereMutex}\n\n\n"
                  end
                }
              end
            
            raiseMutex.synchronize {
              totalThreadsFinished += 1
              print "total done is #{totalThreadsFinished}, now, want #{totalToAllowToFinish}\n"; STDOUT.flush
              if (totalToAllowToFinish and totalThreadsFinished == totalToAllowToFinish and !thrown) or shouldThrow
                if stillHereMutex.locked?
                  thrown = true
                  parentThread.raise ContinueOnward.new("this thread wins! #{argIn}") 
                  
                else
                  print "ARR a thread pool was left early (no longer locked) if interrupted then you're ok, but realize it was interrupted! #{argIn} mutex #{stillHereMutex} -- or this message could mean 'was interrupted, about to cleanem all up' -- check why not cleaning up, tho -- ltodo make sure it cleans up, tho\n"
                end
              end
            }
            rescue raiseThisToInterruptThreads
          end
        }
      end
      sleep
    }
    rescue Exception => detail
    # pass -- ensure that we kill those bad boys!
    if detail.class == ContinueOnward
      # this is ok--threads reached desired count done, or were interrupted mid-stream (hopefully once!) ltodo do this when the thrower happens the first time, and critical it
    elsif detail.class != doneExceptionIfThrown
      print "WARNING we were interrupted early, and we are not killing threads, and the threads might well throw when one of them succeeds--i.e. late! have you guarded them with a lock?" if !interruptThreads and doneExceptionIfThrown != NeverThrown 
    end
    
  ensure
    if interruptThreads
      Thread.critical = true # deny the other threads the pleasure of thinking they won (though they still might...:)
      if defined?(raiseMutex) and raiseMutex
        raiseMutex.synchronize{
          for thread in threads do 
            if thread.alive? 
              if killInsteadOfRaise
                thread.kill
              else
                thread.raise(raiseThisToInterruptThreads.new("generic too slow this time--you lost to another thread so Giveup!")) 
              end 
            end
          end
        }
      else
        error "wow we must have been interrupted super early and hopefully not started any threads, so not stopping any"
      end
      Thread.critical = false
    else
      # let them die (on their own later gracefully)
    end
    
    
    if joinOnAll 
      for thread in threads do thread.join; end
    end
  end
  #  print "\ndone threadrace\n"
  return returnThis # if it happened to have been set ever :) -- only if it said 'breka on success' or what not
end

def testGoodPeers
  require 'open-uri'
  begin
    url = open('http://opendht.org/servers.txt')
    timeLine = url.readline
    allServers = url.read
    url.close
    rescue => detail
    print "ack erred downloading ser"
  end
  allServers = allServers.split("\n")
  allServerArrays = []
  for server in allServers
    allServerArrays << [server.split("\t")[1].split(':')[0], 5851]
  end
  print "begin of 30, top 5, stop after 6:"
  #goodPeers2 = calculateXGoodPeers allServerArrays, 5, 30, 5, 6 # 5s timeout, or after 6 found
  #pp "of 30 random, 5 fastest, stop after get 6, were", goodPeers2
  #print "begin 2 stop after 6, of 100"
  #goodPeers = calculateXGoodPeers allServerArrays, 2, 100, 5, 6 # 5s timeout, or after 6 found
  #pp "got 2 good peers (stop after first 6) 100 random of", goodPeers
  #calculateXGoodPeers peerArrays, totalToGet = 2, numberToTry = 32, maxTimeEachCouldTake = nil, justTakeFirstX = nil
end

class MiddleError < StandardError
end
class TestError < StandardError
end

require 'timeout'
module Timeout
  class << self
    class InternalTimeIsOut < StandardError
    end
    #  Error  is defined there, too
    def timeout(sec, excep = Error, shouldRaise = true)
      return yield if sec == nil or sec.zero?
      stillHereMutex = Mutex.new
      stillHereMutex.synchronize {
        if shouldRaise
          begin
            
            timeThread = Thread.new(Thread.current) { |waitingThread|
              
              sleep sec # tick away
              Thread.critical = true
              waitingThread.raise excep, "execution expired after #{sec} secs}" if waitingThread.alive? and stillHereMutex.locked?  # we're still in the loop--extra exception thrown at us all at once could kick us out
              
              Thread.critical = false # ltodo change it to not require a new mutex every time (save a number)
            }
            answer = yield # run the timed guy
            return answer # ??? ask/point out
          ensure
            if timeThread and timeThread.alive? then timeThread.kill end # might be interrupted, but not a problem the timeThread will just run out, then not raise, as stillHereMutex will no longer be locked.
          end
        else
          begin
            answer = nil
            runningThread = Thread.new { 
              answer = yield
            }
            timeThread = Thread.new(Thread.current) { |parentThread|
              sleep sec
              Thread.critical = true # ha! we win!
              parentThread.raise InternalTimeIsOut if stillHereMutex.locked? # this one doesn't need this check as much, I don't think
              Thread.critical = false
            } # ltodo what if an outside thread injects an interrupt?
            runningThread.join # let it finish
            timeThread.kill
            return answer 
            rescue InternalTimeIsOut
            return runningThread # not interrupted--it is just going!
          ensure
            timeThread.kill if timeThread and timeThread.alive?
            print "abandonment of thread! don't know if this is what you want"
            #pp Thread.current.backtrace
          end
          
        end
      }
    end
  end   #class
end #module 
# ltodo tell ruby they should be able to BT on all outstanding threads, and also to warn when they end and 'arbitrarily' kill some existing threads.
require 'rexml/parsers/baseparser'
module REXML
  module Parsers
    # = Using the Pull Parser
    # <em>This API is experimental, and subject to change.</em>
    #  parser = PullParser.new( "<a>text<b att='val'/>txet</a>" )
    #  while parser.has_next?
    #    res = parser.next
    #    puts res[1]['att'] if res.start_tag? and res[0] == 'b'
    #  end
    # See the PullEvent class for information on the content of the results.
    # The data is identical to the arguments passed for the various events to
    # the StreamListener API.
    #
    # Notice that:
    #  parser = PullParser.new( "<a>BAD DOCUMENT" )
    #  while parser.has_next?
    #    res = parser.next
    #    raise res[1] if res.error?
    #  end
    #
    # Nat Price gave me some good ideas for the API.
    class BaseParser
      
      # Returns the next event.  This is a +PullEvent+ object.
      def pull
        if @closed
          x, @closed = @closed, nil
          return [ :end_element, x ]
        end
        return [ :end_document ] if empty?
        return @stack.shift if @stack.size > 0
        @source.read if @source.buffer.size<2
        #STDERR.puts "BUFFER = #{@source.buffer.inspect}"
        if @document_status == nil
          #@source.consume( /^\s*/um )
          word = @source.match( /^((?:\s+)|(?:<[^>]*>))/um )
          word = word[1] unless word.nil?
          #STDERR.puts "WORD = #{word.inspect}"
          case word
          when COMMENT_START
            return [ :comment, @source.match( COMMENT_PATTERN, true )[1] ]
          when XMLDECL_START
            #STDERR.puts "XMLDECL"
            results = @source.match( XMLDECL_PATTERN, true )[1]
            version = VERSION.match( results )
            version = version[1] unless version.nil?
            encoding = ENCODING.match(results)
            encoding = encoding[1] unless encoding.nil?
            @source.encoding = encoding
            standalone = STANDALONE.match(results)
            standalone = standalone[1] unless standalone.nil?
            return [ :xmldecl, version, encoding, standalone ]
          when INSTRUCTION_START
            return [ :processing_instruction, *@source.match(INSTRUCTION_PATTERN, true)[1,2] ]
          when DOCTYPE_START
            md = @source.match( DOCTYPE_PATTERN, true )
            identity = md[1]
            close = md[2]
            identity =~ IDENTITY
            name = $1
            raise REXML::ParseException("DOCTYPE is missing a name") if name.nil?
            pub_sys = $2.nil? ? nil : $2.strip
            long_name = $3.nil? ? nil : $3.strip
            uri = $4.nil? ? nil : $4.strip
            args = [ :start_doctype, name, pub_sys, long_name, uri ]
            if close == ">"
              @document_status = :after_doctype
              @source.read if @source.buffer.size<2
              md = @source.match(/^\s*/um, true)
              @stack << [ :end_doctype ]
            else
              @document_status = :in_doctype
            end
            return args
          when /^\s+/
          else
            @document_status = :after_doctype
            @source.read if @source.buffer.size<2
            md = @source.match(/\s*/um, true)
          end
        end
        if @document_status == :in_doctype
          md = @source.match(/\s*(.*?>)/um)
          case md[1]
          when SYSTEMENTITY 
            match = @source.match( SYSTEMENTITY, true )[1]
            return [ :externalentity, match ]
            
          when ELEMENTDECL_START
            return [ :elementdecl, @source.match( ELEMENTDECL_PATTERN, true )[1] ]
            
          when ENTITY_START
            match = @source.match( ENTITYDECL, true ).to_a.compact
            match[0] = :entitydecl
            ref = false
            if match[1] == '%'
              ref = true
              match.delete_at 1
            end
            # Now we have to sort out what kind of entity reference this is
            if match[2] == 'SYSTEM'
              # External reference
              match[3] = match[3][1..-2] # PUBID
              match.delete_at(4) if match.size > 4 # Chop out NDATA decl
              # match is [ :entity, name, SYSTEM, pubid(, ndata)? ]
            elsif match[2] == 'PUBLIC'
              # External reference
              match[3] = match[3][1..-2] # PUBID
              match[4] = match[4][1..-2] # HREF
              # match is [ :entity, name, PUBLIC, pubid, href ]
            else
              match[2] = match[2][1..-2]
              match.pop if match.size == 4
              # match is [ :entity, name, value ]
            end
            match << '%' if ref
            return match
          when ATTLISTDECL_START
            md = @source.match( ATTLISTDECL_PATTERN, true )
            raise REXML::ParseException.new( "Bad ATTLIST declaration!", @source ) if md.nil?
            element = md[1]
            contents = md[0]
            
            pairs = {}
            values = md[0].scan( ATTDEF_RE )
            values.each do |attdef|
              unless attdef[3] == "#IMPLIED"
                attdef.compact!
                val = attdef[3]
                val = attdef[4] if val == "#FIXED "
                pairs[attdef[0]] = val
              end
            end
            return [ :attlistdecl, element, pairs, contents ]
          when NOTATIONDECL_START
            md = nil
            if @source.match( PUBLIC )
              md = @source.match( PUBLIC, true )
              vals = [md[1],md[2],md[4],md[6]]
            elsif @source.match( SYSTEM )
              md = @source.match( SYSTEM, true )
              vals = [md[1],md[2],nil,md[4]]
            else
              raise REXML::ParseException.new( "error parsing notation: no matching pattern", @source )
            end
            return [ :notationdecl, *vals ]
          when CDATA_END
            @document_status = :after_doctype
            @source.match( CDATA_END, true )
            return [ :end_doctype ]
          end
        end
        begin
          if @source.buffer[0] == ?<
            if @source.buffer[1] == ?/
              last_tag = @tags.pop
              #md = @source.match_to_consume( '>', CLOSE_MATCH)
              md = @source.match( CLOSE_MATCH, true )
              raise REXML::ParseException.new( "Missing end tag for "+
                "'#{last_tag}' (got \"#{md[1]}\")", 
              @source) unless last_tag == md[1]
              return [ :end_element, last_tag ]
            elsif @source.buffer[1] == ?!
              md = @source.match(/\A(\s*[^>]*>)/um)
              #STDERR.puts "SOURCE BUFFER = #{source.buffer}, #{source.buffer.size}"
              raise REXML::ParseException.new("Malformed node", @source) unless md
              if md[0][2] == ?-
                md = @source.match( COMMENT_PATTERN, true )
                return [ :comment, md[1] ] if md
              else
                md = @source.match( CDATA_PATTERN, true )
                return [ :cdata, md[1] ] if md
              end
              raise REXML::ParseException.new( "Declarations can only occur "+
                "in the doctype declaration.", @source)
            elsif @source.buffer[1] == ??
              md = @source.match( INSTRUCTION_PATTERN, true )
              return [ :processing_instruction, md[1], md[2] ] if md
              raise REXML::ParseException.new( "Bad instruction declaration",
              @source)
            else
              # Get the next tag
              md = @source.match(TAG_MATCH, true)
              unless md
                # Check for missing attribute quotes
                raise REXML::ParseException.new("missing attribute quote", @source) if @source.match(MISSING_ATTRIBUTE_QUOTES )
                raise REXML::ParseException.new("malformed XML: missing tag start", @source) 
              end
              attrs = []
              if md[2].size > 0
                attrs = md[2].scan( ATTRIBUTE_PATTERN )
                raise REXML::ParseException.new( "error parsing attributes: [#{attrs.join ', '}], excess = \"#$'\"", @source) if $' and $'.strip.size > 0
              end
              
              if md[4]
                @closed = md[1]
              else
                @tags.push( md[1] )
              end
              attributes = {}
              attrs.each { |a,b,c| attributes[a] = c }
              return [ :start_element, md[1], attributes ]
            end
          else
            md = @source.match( TEXT_PATTERN, true )
            if md[0].length == 0
              @source.match( /(\s+)/, true )
            end
            #STDERR.puts "GOT #{md[1].inspect}" unless md[0].length == 0
            #return [ :text, "" ] if md[0].length == 0
            # unnormalized = Text::unnormalize( md[1], self )
            # return PullEvent.new( :text, md[1], unnormalized )
            return [ :text, md[1] ]
          end
          rescue REXML::ParseException
          raise
          rescue Exception, NameError => error
          # here it catches the old exception, trnaslates it--that ain't good
          raise error.class.new(error.to_s + "baseparser grabbed it ") # mine
          #          raise REXML::ParseException.new( "baseparser Exception parsing",
          #            @source, self, (error ? error : $!) )
        end
        return [ :dummy ]
      end
      
    end
  end
end

class Fixnum
  
  def kb
    return self*1000
  end
  alias :kbps :kb
  
  def mb
    return self*1000000
  end
  alias :mbps :mb
  def bps; self; end
  
end


def usefulTestSelf
  TCPSocketConnectionAware.testSelf
  answer = Timeout::timeout(1, TestError, false) { sleep }
  assert answer
  assert answer.class == Thread
  answer.kill
  
  begin
    answer = Timeout::timeout(1, TestError, true) { sleep }
    assert false
    rescue TestError
    assert true
  end
  
  assertEqual Dir.stripEndingPathAspectStartingWithNoEndingSlashReturningAnEndingSlash("/b"), "/"
  assertEqual Dir.stripEndingPathAspectStartingWithNoEndingSlashReturningAnEndingSlash("/a/b"), "/a/"
  assertEqual Dir.stripEndingPathAspectStartingWithNoEndingSlashReturningAnEndingSlash("a/b"), "a/"
  assertEqual Dir.stripEndingPathAspectStartingWithNoEndingSlashReturningAnEndingSlash("../b"), "../"
  assertEqual Dir.stripEndingPathAspectStartingWithNoEndingSlashReturningAnEndingSlash("b"), ""
  assertEqual Dir.stripEndingPathAspectStartingWithNoEndingSlashReturningAnEndingSlash(""), ""
  assert("a/".stripEnding('/') == "a")
  assert("a/".stripEnding('b') == "a/")
  testGoodPeers
  total = 0
  threadRaceInjectsGiveUp(Array.new(32), 3) { |notUsed| 
    myNumber = total
    total += 1
    assert total < 15 # allow for some overflow
  }
  total = 0
  threadRaceInjectsGiveUp(Array.new(32), 3000, false) { |notUsed|
    myNumber = total
    total += 1
  }
  assertEqual total, 32
  
  total = 0
  semaphore = Mutex.new
  threadRaceInjectsGiveUp(Array.new(32), 3000, true, MiddleError) { |notUsed|
    myNumber = total
    semaphore.synchronize {
      total += 1
      if myNumber == 15
        raise MiddleError.new("mid stream!")
      end 
    }
  }
  sleep 0.1
  dbg
  assert total < 20, "total was #{total} which is >= 20, we expected only 15!"
  print "from raising at 15, we got total #{total}\n"
  total = 0
  threadRaceInjectsGiveUp(Array.new(32), 3000, true, MiddleError) { |notUsed| total += 1 }
  assertEqual total, 32 # should work
  
end

if runOrRunDebug?( __FILE__)
  usefulTestSelf
end

