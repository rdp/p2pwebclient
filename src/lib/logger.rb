require 'thread' # Mutex

module Logs
 def prefix m
   "#{@log_prefix}:" << m # getting a nil error here is a 'real' error--don't pass those in! :) 
 end
 
 def debug message
   if @parent
     @parent.debug prefix(message)
   else
     @logger.debug prefix(message)
   end
 end
 
 def log message
   if @parent
      @parent.log prefix(message)
   else
     if @logger
     	@logger.log prefix(message) 
     else
	print 'WARNING NO LOGGER FOR' << message  
     end
   end
 end
 
 def error message
  if @parent
    @parent.error prefix(message)
  else
    @logger.error prefix(message)
  end
 end
end

class Logger
  @@output_to_file_only_not_screen = false  
  def initialize(thisFileName, startTime = 0, permanentPrefix = rand(100000), thisHandleToUseInsteadOfOpeningAFile = nil) # ltodo call it prefix
    begin
      raise unless thisFileName.class == String
      @logFile = thisHandleToUseInsteadOfOpeningAFile || File.new(thisFileName, "ab") # append
      @filename = thisFileName
      # so they hand us start second 30
      # our time says 1000
      # then 1001
      # so we want a better '0' or to coordinate the startTime passed to us with our clock on this sytems
      # original start time to be such that Time.now - x = Time.now - Time.start + original
      # x = Time.start - original
      @startSubtractTime = Time.new.to_f - startTime # ltodo tighter start time [pass in a time when received it]:)
      @writeMutex = Mutex.new
      @permanentPrefix = permanentPrefix
      setPostPrefix(nil)
      log "starting up logger (version #{$version}) to #{thisFileName}"
    rescue => e
      print 'logger died on init!!! BAD!', e.to_s
      raise
    end
  end
  
  attr_reader :logFile # allow us to create some logger copy guys
  
  def read_whole_file
    if @logFile
      @logFile.flush 
      File.read @logFile.path
    else
      File.read @logOldFilename
    end
  end
  
  def setPostPrefix(toThis)
    if toThis
      toThis = ' ' + toThis
    else
      toThis = ''
    end
    @labelPostTime = '[' + @permanentPrefix.to_s + toThis + ']'
  end
  
  def formatMessage(message)
    if message[-2..-1] != "\r\n"
      message += "\r\n"
    end
    timeAt = Time.new.to_f - @startSubtractTime 
    return  ("%.3f" % timeAt) + @labelPostTime + message
  end
  attr_accessor :raise_on_more_messages
  attr_accessor :messages_received_after_close
  def log(message)
    begin
      newMessage = formatMessage(message)
      print newMessage unless @@output_to_file_only_not_screen
      if !@logFile
        @messages_received_after_close ||= 0
        @messages_received_after_close += 1
        print "ERROR LOGGING THIS!!\n\n\n" # ltodo don't allow this...muhaha
        return
      end
      assert @logFile and !@logFile.closed?
      @logFile.write(newMessage)
      @logFile.flush
      # umm this stinks and errs at times...as EBADF on windows @logFile.flush # for my benefit ltodo take off for speed :)
    rescue Exception => detail  # ltodo tighten down on these
      assert detail.class != P2PTransferInterrupt
      newMessage = formatMessage(message + "[<=mess] weird unable to write to file (anticipate EINVAL win32) [#{detail} #{detail.class}]" )
      if detail.class != Errno::EPIPE and detail.class != Errno::EINVAL
        newMessage += "ERROR " + detail.to_s + detail.backtrace.join('...') # ltodo ruby rug report these weirdies
      end
      
      begin 
        print newMessage
        @logFile.write(newMessage)
      rescue Exception => detail
        # assume printing won't err :)
        print "\nSEEDO UNABLE TO write message to log file twice in a row! #{message} #{detail} #{detail.class}\n\n\n\n\n\n" + newMessage
        raise unless detail.class == Errno::EINVAL and RUBY_PLATFORM =~ /mingw|win32/ # which is quite possible on win32 when you run out of buffer space, I believe.
      end
      raise unless detail.class == Errno::EINVAL and RUBY_PLATFORM =~ /mingw|win32/
      
    end
    
  end
  
  def closed?
    if @logFile
      return false
    else
      return true
    end
  end
  # ltodo look more carefully into teh case of a 'write select clearing, then not reading anything'
  def close
    debug "closing logger [to #{@filename}]"
    assert @logFile
    #    @logFile.flush # attempt to avoid deletion error on close ltodo tell ruby their logfile.close is not thread safe (?):
    # ltodo did this help it?
    @logFile.close 
    @logOldFilename = @logFile.path
    @logFile = nil # for error checking.  Or does this cause some big problems?
  end
  
  def debug(message)
    message = "DEBUG:" + message
    log(message)
  end
  
  def error(message)
    debug("ERROR:"  + message)
  end
  
  def warn(message)
    debug("WARNING:" + message);
  end # ltodo
  
end # class
