#!/usr/bin/ruby
#
# Roger's somewhat real client
#
# 
require 'socket' # blockSize
require 'constants'
require 'pp'
require 'lib/timeKeeper.rb'
require 'listener.rb'
require 'generic_client.rb'

class CSP2PGetter
  attr_reader :blockManager
  # ltodo do rm's a few at a time... :)
  @@MaxCSAndP2PTimeDownloading = 30.minutesAsSeconds
  
  # ltodo add this function to tests..
  # This is used by the driver so it can keep going easily :)

  def debug a
    @logger.debug a
  end
  
  def log a
    @logger.log a
    
  end
  
  def error a
    @logger.error a
  end

  
  def lingerAndClose(howLong)
    begin
      @p2pGetter.lingerBlockingAndKillPeerThreads(howLong) # note that it lingers regardless of whether P2P/CS was used
      @p2pGetter.sendServerStopMessage
      rescue => detail
      @logger.error "SEEDO LINGER DIED!!! MEEP MEEP" + detail.to_s + detail.backtrace.join('...')
    end
    
    begin
      debug "now unlisting self"
      @blockManager.unlistSelfAllBlocksParallelBlocking
      debug "going to wait on opendht"
      # now just in case there let some sets, file size sets to finish
      @opendht.waitForOpenThreadsToClose 
      debug "done waiting on opendht"
      rescue => detail
      @logger.error "SEEDO opendht!" + detail.to_s
    end
    
    begin
      debug "joinign on server"
      @p2pGetter.joinOnStoppedServer
      assert @p2pGetter.serverStopped?
      rescue => detail
      @logger.error "SEEDO joinger died joinonStoppedServer"
    end
    
    begin
      if not blockManager.fileIsCorrect?
        filename = '../logs/bad' + @clientNumber.to_s + ".bad_file.txt"
        error "SEEDO YIKES BAD DATA or incomplete file!! saving #{filename}"
        blockManager.writeToFile(filename)
      end
      debug "done with lingeradnclose"
      rescue => detail
      @logger.error "SEEDO threw error in file is correct! bad!" + detail.to_s + detail.class.to_s
    end
    
    begin
      @blockManager.deleteBlocks
    rescue => detail
      @logger.error "SEEDO delete block DIED????" + detail.to_s
    end
  end
  
  def done?
    return @blockManager.done?
  end
  
end # class

