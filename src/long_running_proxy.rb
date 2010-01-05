#!/usr/bin/env ruby
require 'constants'
#
# so this represents kind of a codeen style proxy--either just 'request files from it' (if they're static), or request http://localhost:port/other_file_name or http://localhost:port/http://host:port/other_file_name
# the last one being so you can copy and paste most easily muhaha
#
# guess from work I'll need to run this "directly" on bp
#
class Proxy < EM::Connection
  @@request_count = 0
  @@all_file_getters = {}
  def receive_data requestIncoming
    LOGGER.debug "got request #{requestIncoming}" 
    file, host, port, startByte, endByte, type, fullUrl = TCPSocketConnectionAware.parseHTTPRequest(requestIncoming) # assume it's a request
    if port == MY_PORT # ignore the host name--it will always be something or other that "is" us
      # in this case expect a request like /hostname.com:port/file/subdir
      if file.index('/http://') == 0
	file = file[7..-1] # strip off a beginning http://, allowing for requests like http://localhost:port/http://host:port/filename, and leave the last '/'
      end
      host_port, url = file.split('/')[1], file.split('/')[2..-1] # strip out host name
      host, port = host_port.split(':')
      port ||= 80
      file = url.join('/')
      fullUrl = "http://#{host_port}/#{file}"
    end
    linger = 20000
    dr = 160_000
    @logger = LOGGER
    my_number = @@request_count
    @@request_count += 1
    @log_prefix = @@request_count.to_s
    debug 'getting' + [file, host, port, startByte, endByte, type, fullUrl].join(', ')
    @fullUrl = fullUrl
    dt = 3
    @getter = @@all_file_getters[fullUrl] ||= BlockManager.startCSWithP2PEM(fullUrl, :dTToWaitAtBeginning => 3, :dWindowSeconds => 3, :dRIfBelowThisCutItBps => dr, :blockSize => 1_000_000, :spaceBetweenNew => 77, :linger => linger, :startTime => 9, :peer_name => my_number,:totalSecondsToContinueGeneratingNewClients => 1, :runName => 'get' + fullUrl[0..20].sanitize + Time.now.to_f.to_s, :serverBpS => 5,:peer_tokens => 20, :generic_logger => LOGGER)

    @getter.restart_if_had_been_interrupted
    last_byte_received_and_sent = -1
    @already_sent_header = false
    @send_timer = nil

    maximum_BPS = 50_000_000#4_000_000_000 # empirically this only goes to like 4MB/s anyway since it has to queue, then get back to you. Bleh.
    EM::set_timer_quantum(5)#MS
    time_interval = 0.005
    check_again_if_none_to_send_interval = time_interval
    block_size = maximum_BPS*time_interval
    queue_block_size = block_size/5
    queue_if_falls_below_this = maximum_BPS*time_interval/2.0 # /2 so that on average we are at about our BPS...maybe

    # why not? -- this could maybe use some help
    # so right now it still does some queueing, up to that size...maybe?
    # right now it combats both N^2 queueing and long queueing.  Not sure if those are good, bad, whatever.
   
    send_proc = proc { 
      LOGGER.debug 'send proc'
      if (@getter.done? and (last_byte_received_and_sent == (@getter.wholeFileSize - 1))) or @getter.opendht_done_and_logger_closed # meaning toast
      
	LOGGER.log "done queueing/sending whole file, I must presume"
	close_connection_after_writing
        return
      end

      write_up_to_this_byte = @getter.next_finishing_byte_done_after last_byte_received_and_sent
      if write_up_to_this_byte != last_byte_received_and_sent
        attempt_send_header
        LOGGER.log "#{my_number} go! sending more good bytes #{last_byte_received_and_sent + 1} -> #{write_up_to_this_byte}" 

        sending_place_marker = last_byte_received_and_sent + 1 # ltodo clean up

        if sending_place_marker <= write_up_to_this_byte
           end_place = [sending_place_marker + queue_block_size, write_up_to_this_byte].min
	   LOGGER.debug "queueing #{sending_place_marker} => #{end_place}"
           send_data @getter.getBytesToReturnToPeerIncludingEndByte(sending_place_marker, end_place) # ltodo add a 'real' output, not this timed junk
           sending_place_marker = end_place + 1
	   last_byte_received_and_sent = end_place
           if get_outbound_data_size > queue_if_falls_below_this
               LOGGER.debug 'done queueing -- setting it for a long time ahead NEXT TICKING ANYWAY'
               EM::next_tick send_proc
               return
           else
               LOGGER.debug 'next ticking it!'
	       EM::next_tick send_proc
           end
        end
      else
  	LOGGER.log "#{my_number} no new stuff--at byte #{last_byte_received_and_sent}" if rand(32) == 0
        EM::Timer.new check_again_if_none_to_send_interval, send_proc
      end
    }
    send_proc.call
  end

  include Logs

  def unbind
   log 'unbind called'
   @send_timer.cancel  if @send_timer
   # if they give up on us--give up on them
   @@all_file_getters[@fullUrl].hard_interrupt_download if @fullUrl and !@@all_file_getters[@fullUrl].done?
 end

  def attempt_send_header # necessary because curl requires it for some reason
    return if @already_sent_header
    return unless @getter.fileSizeSet?
    header = TCPSocketConnectionAware.createReturnHeader 0, @getter.wholeFileSize - 1, @getter.wholeFileSize
    send_data header
    @already_sent_header = true
  end
end

port = ARGV[0] || "8888"
port = port.to_i
logger = Logger.new('proxy_' + port.to_s, 0)
logger.log 'starting proxy on port' + port.to_s

EM::run {
   Proxy.const_set('LOGGER', logger)
   Proxy.const_set('MY_PORT', port)
   EventMachine::start_server('0.0.0.0', port, Proxy) { |clientConnection| 
     # nothing
   }
   logger.debug 'started server'
}






