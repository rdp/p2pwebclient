begin
  require 'rubygems'
  rescue Exception => e
end

require 'eventmachine'

module EventMachine
  def EventMachine.connect_from_other_thread *args, &block
	EM::next_tick {
		begin
			EM::connect *args, &block
		rescue RuntimeError
			print "WARNING connect from other thread failed! #{args}"
		end
	}
  end  
  
  def self.start_epoll_many_descriptors to_this_user # todo change user after!
    EventMachine.epoll
    # unstable!!! EventMachine.kqueue if Socket.gethostname() =~ /roger/i
    self.grab_lotsa_descriptors
  end

  def self.grab_lotsa_descriptors
    60.downto(1) do |n|
      if EventMachine.set_descriptor_table_size(n*1000) == n*1000
        print n*1000, 'descriptors given! run sudo for more!'
        break
      end
    end
  end

  def EventMachine::convertNumberToString em_num
   return 'timerfired' if em_num == 100
   return 'ConnectionData' if em_num == 101
   return 'ConnectionUnbound' if em_num == 102
   return 'ConnectionAccepted' if em_num == 103
   return 'connectionCompleted' if em_num == 104
   return 'LoopbreakSignalled' if em_num == 105
   return 'unknown!!!'
  end
 
  class Connection
           def get_sockname
                EventMachine::get_sockname @signature
        end
       
    def get_tcp_connection_info_hash
      # handles just TCP for now
      peer_port, peer_host = Socket.unpack_sockaddr_in(self.get_peername) if self.get_peername
      local_stuff = self.get_sockname rescue nil
      local_port = local_host = nil # odd that it can do this in win32...very odd ltodo
      local_port, local_host = Socket.unpack_sockaddr_in(local_stuff) if local_stuff
      #assert local_port
      return {:peer_port => peer_port, :peer_host => peer_host, :local_port => local_port, :local_host => local_host}
    end

  end
  
  
  @startMutex = Mutex.new
  def EventMachine.fireSelfUp
    @startMutex.synchronize {
      if !EventMachine::reactor_running?
        @running_thread = Thread.new { 
          EM.run {}
        }
        sleep 0 while !EventMachine::reactor_running?  # let it start
      else
        nil
      end
    }
  end
  
  def EventMachine::shutdownGracefully # ltodo put in listener
    EventMachine::stop if EventMachine::reactor_running?
    if @running_thread
      @running_thread.join
    else
      print 'odd to calls hutdown without having called fireSelfUp'
      sleep 0 while EventMachine::reactor_running?
    end
  end
end


def fileDescriptorsAvailable
   count = 0
   all = []
   loop {
	begin
	  all << File.open('/dev/null')
	  count += 1
        rescue
	  break
        end
	}
   all.each{|file| file.close}
   count
end


class SingleConnectionCompleted < EventMachine::Connection
  attr_accessor :connection_completed_block
  attr_accessor :unbind_block
  attr_accessor :receive_data_block
  def connection_completed
    self.set_comm_inactivity_timeout 60 # hard coded, but hey
    @connection_completed_block.call(self) if @connection_completed_block
    # we can't close here, in case the other side should send us something back then we desire to close
  end
  
  def receive_data data
    @receive_data_block.call(self, data) if @receive_data_block
  end
  
  def unbind
    @unbind_block.call(self) if @unbind_block
  end
end

module EventMachine
  # a thread safe 'ask EM is a port is open and sleep until it knows the answer'
  def EventMachine.portOpen? host, port, timeout = nil
    open = false
    cv = SpringsOnce.new # eh
      unbind_proc = proc {
        cv.signalToAlwaysOpen
      }
      conn_success = proc { |conn|
        open = true
        cv.signalToAlwaysOpen
        conn.close_connection
      }
      
      EM::connect(host, port, SingleConnectionCompleted) { |conn|
        conn.set_comm_inactivity_timeout timeout if timeout
        conn.connection_completed_block = conn_success
        conn.unbind_block = unbind_proc
      }
      cv.waitUnlessAlreadySprung # release it
    open
  end
  
end

# I want one that is 
# a = SpringsOnce.new
# a.waitUnlessAlreadySprung
# (later)
# a.signalToAlwaysOpen

require 'thread'

class SpringsOnce
  
  def initialize *args
    @modify_mutex = Mutex.new # ltodo could be a class var, I think
    @signalThisCV = ConditionVariable.new
    @sprung = false
 #   @waiting = nil
  end
  
  def waitUnlessAlreadySprung # ltodo rename waitUnlessAlreadyOpen
    @modify_mutex.synchronize {
        #@waiting = Thread.current # was @signalthis.wait...egh!
        @signalThisCV.wait(@modify_mutex) unless @sprung
    }
#    sleep # forever! Could this be interrupted?
  end
  
  def signalToAlwaysOpen
    @sprung = true
    @modify_mutex.synchronize {
      @sprung = true
      @signalThisCV.signal # why not :)
      if @waiting
#        sleep 0 and print "deathy!" if @waiting.status != "sleep"
     #   assert @waiting.status == "sleep"
#        sleep 0 and print "deathy!bad!!!!well maybe ok :) !\n\n\n\n\n\n\n" if @waiting.status != "sleep"
#        @waiting.wakeup
      end
    }
  end
  
end

#def calculateXGoodPeers peerArrays, totalToGet = 2, numberToTry = 32, maxTimeEachCouldTake = nil, justTakeFirstX = nil, keepSocketsOpen = false, killThreads = true # justTakeFirstX means 'after 10 are back, choose first 5'

# DO NOT CALL WITH TOO MANY to get taht will block or it might...just about never return
def calculateXQuickestPorts peerArrays, totalToGet = peerArrays.length, numberToTry = peerArrays.length # note we lack a few things, like a real timeout...
  print "needs to be redone don't use yet!\n\n\n"
  totalToGet = [totalToGet, peerArrays.length].min
  numberToTry = [numberToTry, peerArrays.length].min
  randomizedArray = peerArrays.randomizedVersion[0..numberToTry - 1] # all we need
  successArray = []
  successMutex = Mutex.new
  sumSucceeded = 0
  done = SpringsOnce.new
  allConnections = []
  begin
      sumDoneOrFailed = 0
      unbind_proc = proc {
        sumDoneOrFailed += 1
        if sumDoneOrFailed == numberToTry
          print 'ack conking calculate x good peers!!!'

        end
      } # ltodo test this...
      conn_success = proc { | conn|
        successMutex.synchronize {
          if sumSucceeded < totalToGet
            sumSucceeded += 1
            info = conn.get_tcp_connection_info_hash
            successArray << [info[:host], info[:port]]
            if sumSucceeded == totalToGet
              done.signalToAlwaysOpen
            end
            # really wants to next_tick something here like a defered proc
          else
            # too late!
            #             print 'too late'
            #             pp [server, port]
          end
        }
      }
      
      randomizedArray.each do |server, port|
        EM::connect(server, port, SingleConnectionCompleted) { |conn|
          conn.connection_completed_block = conn_success
          conn.unbind_block = unbind_proc
          allConnections << conn
        }
      end
      done.waitUnlessAlreadySprung
  ensure
    for conn in allConnections do
      conn.close_connection # attempt to free file descriptors!
    end
  end
  successArray
end
