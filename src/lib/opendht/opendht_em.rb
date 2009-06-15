require File.dirname(__FILE__) + '/../../constants' if File.exist?(File.dirname(__FILE__) + '/../../constants.rb')  # already requires 'create_named_parameters_wrapper' for us

class OpenDHTEM
  attr_reader :logger
  # stinky todo--do we need round AND description?  We could just rename it unique_description and hope they pass us a unique one, and use it uniquely internally (as we already do)
  
  # gateway_pool_size creates a pool that are used in round robin fashion for adds/rm's, max_num at a time for gets (simultaneous, parallel)
  use_opendht = false

  if use_opendht
    StartingGateways = [['opendht.nyuld.net', 5851]]
    Opendht_servers_file ="servers.txt"
  elsif false #Socket.gethostname =~ /roger.*macbook/
    StartingGateways = [['localhost', 3633]]
    Opendht_servers_file ="lib/opendht/cached_all_gateways_file_name_roger_macbook"
  else # the default use

    ips = {'planetlab3.flux.utah.edu' => ['155.98.35.4', 3641], 'planetlab1.flux.utah.edu' => ['155.98.35.2', 3631], 'planetlab2.flux.utah.edu' => ['155.98.35.3', 3631], 'planetlab4.flux.utah.edu' => ['155.98.35.5', 3641], 'planetlab5.flux.utah.edu' => ['155.98.35.6', 3631]}

    StartingGateways = ips.values # central points of failure are bad todor
    Opendht_servers_file ="lib/opendht/cached_all_gateways_file_name"
  end

  def initialize logger, key_multiply_redundancy = 1, max_num_simultaneous_gateway_requests_per_query = key_multiply_redundancy, gateway_pool_size = 1, gateway_pool_creation_race_size = 0 # these typically come back very quicky, but still...we'll keep pool size and pool creation race size close in number to free up some descriptors for ourselves :)
    raise "max_num_simultaneous_gateway_requests_per_query #{max_num_simultaneous_gateway_requests_per_query} must be a multiple of key_multiply_redundancy #{key_multiply_redundancy}" if max_num_simultaneous_gateway_requests_per_query % key_multiply_redundancy != 0
    @logger = logger
    @log_prefix = "odhtem"
    @retry_times_if_non_successful_answer = 2
    @key_multiply_redundancy = key_multiply_redundancy
    assert gateway_pool_size != 0 && gateway_pool_size, "you have to have a gateway_pool_size of at least 1--doesn't make sense to not have any gateway pools and the default is size 1"
    if gateway_pool_size
      @num_simultaneous_gateway_requests_per_query = [max_num_simultaneous_gateway_requests_per_query, gateway_pool_size].min
    else
      @num_simultaneous_gateway_requests_per_query = 1 # just use the opendht.nyuld.net one, so only once is advised :)
    end  
    error 'whoa you are going to be doubling up on gets (more than one per gateway)--maybe ok' if total_get_responses_expected > gateway_pool_size
    @gateways = StartingGateways.dup # start with the default -- was opendht.nyuld.net 5851 # TODO setup static!
    @outstanding_conns_still_open = {}
    @secret = 'secret' # lame :)
    @ttl = 5*60
    @application ='p2pwebclient'
    @max_return_values = 100000
    @done_finding_live_gateways = true
    calculate_new_live_gateways gateway_pool_creation_race_size unless gateway_pool_creation_race_size == 0 
    assert gateway_pool_creation_race_size >= 0
    @latest_place_markers = {} # key => pm, always assume latest is better. (most current) store them here
    @gateway_grab_mutex = Mutex.new
    @func_to_call_when_empty_which_means_we_are_in_shutdown_mode = nil
  end
  create_named_parameters_wrapper :initialize
  attr_reader :done_finding_live_gateways

  def log m
	if @logger
		@logger.log @log_prefix + m if @logger
	else
		print 'log ', m, "\n"
	end
  end

  def error m
	if @logger
		@logger.error @log_prefix + m if @logger
	else
		print "err", m, "\n"
	end
  end

  def debug m
	if @logger
		@logger.debug @log_prefix + m if @logger
	else
		print m, "\n"
	end
  end

  attr_reader :application, :max_return_values, :ttl, :application, :secret, :outstanding_conns_still_open
  attr_accessor :gateways, :default_return_proc # for debugging ltodo delete
  attr_accessor :func_to_call_when_empty_which_means_we_are_in_shutdown_mode
  
  # doctest_require: '../logger'
  # doctest:
  # when we have only a few running opendht instances, eventually it should find them all, even if its 'out of lots'
  # >> require 'facets'
  # >> OpenDHTEM.class_eval "Opendht_servers_file = 'fake_dht_list'"
  # >> string = ''
  # >> 10.times {|n| string += "0:\tlocalhost:#{n+9000}\n"}
  # >> File.write 'fake_dht_list', string
  # with 5 servers it should find 5 very quickly.
  # >> 5.times { |n| Thread.new {TCPserver.open(n + 9004).accept}}
  # >> EM::fireSelfUp
  # >> subject = OpenDHTEM.new(Logger.new('test_logger_file'), :gateway_pool_size => 10 )
  # >> sleep 1
  # => 1
  # >> subject.instance_variable_get(:@gateways).length
  # => 5
  
  def calculate_new_live_gateways total_fast_to_try
    if @func_to_call_when_empty_which_means_we_are_in_shutdown_mode and @outstanding_conns_still_open.length == 0 # if we are in shutdown mode, we no longer need or want to search for openDHT proxies
	    debug "no longer attempting more gateways -- we were told that you_can_stop_searching_for_gateways_now"
	    done_searching_for_live_gateways
	  return
    end
    @done_finding_live_gateways = false
    unless defined?(@allServerArrays)
      allServers = nil
      allServers = File.read(Opendht_servers_file)
      # ot sure if this line does anything, even...probably works, though      download_http_unique_across_processes 'opendht.org.nyud.net', 80, '/servers.txt', Opendht_servers_file if ((File.ctime Opendht_servers_file) - Time.now)/60/60/24 > 1 # if it's a day old, get a new copy exclusively TODOR fix?
      allServers = allServers.split("\n")
      allServers.shift unless allServers[0].include? "\t"# first line is date and time--if it is, that is.  The 'old' way, which is to actually download
      allServerArrays = []
      for server in allServers
        name, port = server.split("\t")[1].split(':')
        allServerArrays << [name, port.to_i]
      end
      @allServerArrays = allServerArrays.randomizedVersion
    end

    if @allServerArrays == nil or @allServerArrays.length == 0
       @num_simultaneous_gateway_requests_per_query = [[@num_simultaneous_gateway_requests_per_query, @gateways.length].min, 1].max # at least one, at most @num_simultaneous
       error "uh oh ran out of other opendhts to try-- now forced to and set max at #{@num_simultaneous_gateway_requests_per_query} #{@gateways.inspect}"
       done_searching_for_live_gateways
       return
    end

    randomizedArray = @allServerArrays[0..(total_fast_to_try -1)]
    @allServerArrays = @allServerArrays[total_fast_to_try..-1]
    total_expected_responses = randomizedArray.length
    total_got_so_far = 0
    total_reported = 0
    randomizedArray.each do |server_common, port_common|
      begin
        server = server_common
        port = port_common
        EM::connect(server, port, SingleConnectionCompleted) { |conn|
          # this block is run immediately, so there are no variable scoping conflicts--incomign is safely saved away...
          conn.instance_variable_set(:@host, server)
          conn.instance_variable_set(:@port, port)
          incoming = [server, port]
          conn.connection_completed_block = proc { 
            if total_got_so_far < total_fast_to_try
              total_got_so_far += 1
              debug "adding fast gw #{incoming.inspect} -- size now #{@gateways.length + 1}"
              if @gateways == StartingGateways
                @gateways = [incoming]
              else
                @gateways << incoming
              end
            else
              debug "not adding late (presumably far away) gw #{incoming.inspect}"
            end
            conn.close_connection
            conn.instance_variable_set(:@answered, true)
          }
          conn.unbind_block = proc {
            # note: the unbind block is ALWAYS called :)
            incoming = [conn.instance_variable_get(:@host), conn.instance_variable_get(:@port)] # ltodo just use get_peername
            if !conn.instance_variable_get(:@answered)
              debug "bad opendht server:#{incoming.inspect}"
	          end
            total_reported += 1
            if total_reported == total_expected_responses 
             
              if total_got_so_far < total_fast_to_try
                debug "uh oh repolling--did not poll enough opendht servers to get my previously thought minimum! #{total_got_so_far} < #{total_fast_to_try}--retrying some more--total we have now is #{@gateways.length}"
		            calculate_new_live_gateways total_fast_to_try - total_got_so_far
              else
		            debug "got at least enough opendht servers! #{@gateways.length}"
                done_searching_for_live_gateways
              end
            end
          }
        }
      rescue StandardError => e
        debug "apparently just tried a poor [not working] opendht #{server} #{port} for fast gateway search #{e}" 
      end
    end
    
  end

  def done_searching_for_live_gateways
      @done_finding_live_gateways = true
      check_for_and_do_final_shutdown_if_should
  end

  def total_get_responses_expected
    return @key_multiply_redundancy * how_many_times_to_repeat_get_keys_to_different_gateways
  end
  
  
  def register_in_oustanding internal_round_id, description
    assert internal_round_id
    assert !@outstanding_conns_still_open[internal_round_id]
    @outstanding_conns_still_open[internal_round_id] = description
  end
  
  def check_for_and_do_final_shutdown_if_should
    if @func_to_call_when_empty_which_means_we_are_in_shutdown_mode and @outstanding_conns_still_open.length == 0 and @done_finding_live_gateways
      debug "calling global shutdown func [its creation to avoid polling]"
      @func_to_call_when_empty_which_means_we_are_in_shutdown_mode.call 
      @func_to_call_when_empty_which_means_we_are_in_shutdown_mode = nil
    end
  end
  
  def unregister_from_outstanding_and_possibly_call_global_end_proc internal_round_id, return_status, description, start_time
    assert internal_round_id
    assert @outstanding_conns_still_open.delete(internal_round_id)
    check_for_and_do_final_shutdown_if_should
  end
  
  def next_gateway
    assert @gateways and !@gateways.blank?
    @gateway_grab_mutex.synchronize {
      gw = @gateways.shift
      @gateways << gw # put at back at the end :)
      gw
    }
  end
  
  def do_multiple_keys_single_action key, round_id, description, repeat_extra_times_past_this, on_done_proc = nil, max_keys_to_use = nil, &block
    round_id = round_id.to_s
    keys = multiply_keys(key)
    keys = keys[0..(max_keys_to_use-1)] if max_keys_to_use # allow for low intensity requests
    for key_real in keys do
      do_single_key_single_action key_real, round_id, description, repeat_extra_times_past_this, on_done_proc, &block
    end
  end
  
  @@uid_per_transaction = 0

  def do_single_key_single_action key_new, round_id, description, repeat_extra_times_past_this, on_done_proc, &block
    raise unless block
    raise unless repeat_extra_times_past_this
    assert repeat_extra_times_past_this >= 0
    assert block_given?
    assertEqual repeat_extra_times_past_this.class, Fixnum
    ODHTTransport.setup(self, description, round_id, key_new, on_done_proc) { |conn, host, port| # ltodo rename on_done_proc same for all func's that have one
      start_time = Time.now
      debug "description[#{description}] round[#{round_id}] key[#{key_new}] #{start_time.to_f} #{host} #{port}"
      uid = "#{description.gsub(':', '_')} ##{@@uid_per_transaction += 1} #{host} #{port}"
      log "pre opendht #{description} repeat_extra_times_past_this:#{repeat_extra_times_past_this} uid:#{uid}:"
      register_in_oustanding uid, true
      conn.set_finalize_function proc { |return_status, values, key_used| 
        assertEqual key_used, key_new
        log "post opendht #{description} => #{return_status} in #{Time.new - start_time}s (gw: #{host}:#{port}) uid:#{uid}:" 	
        if return_status == :success or repeat_extra_times_past_this == 0 
          debug "done with this round because (#{return_status}==:success || #{repeat_extra_times_past_this}==0)"
          on_done_proc.call(return_status, values, round_id, key_new) if on_done_proc # call back their functions, should they desire
          unregister_from_outstanding_and_possibly_call_global_end_proc(uid, return_status, description, start_time) # we want unregister here, so that if doing an 'out call' sparks another DHT, we won't prematurely call @func_to_call_when_empty_which_means_we_are_in_shutdown_mode--i.e. it ensures everything's taken care of
        else
          error "repeating for erring! #{description} #{repeat_extra_times_past_this}x left"
          do_single_key_single_action key_new, round_id, description, repeat_extra_times_past_this - 1, on_done_proc, &block
          unregister_from_outstanding_and_possibly_call_global_end_proc(uid, return_status, description, start_time)
        end
      }
      yield(conn, key_new) # yield it once to them -- they call add, etc, on it. stinky!
    }
    
  end
  
  def remove key, value, round_id = nil, description = '', done_proc = nil, &block
    block ||= done_proc || @default_return_proc
    round_id ||= key + value.to_s + rand(1000000).to_s
    description = "rm [#{key}  -= #{value}]" << description
    do_multiple_keys_single_action(key, round_id, description, @retry_times_if_non_successful_answer, block) { |conn, new_key|
      conn.rm new_key, value
    }
  end
  create_named_parameters_wrapper :remove
  
  # ltodo create a function 'just give me all the existing, no complaints, in one array!' err rather show examples of this, when give to world -- should be just to create it with just one gateway, show how to pass a func.
  private
  def how_many_times_to_repeat_get_keys_to_different_gateways
    # so my question is if we have 3 keys, and 6 gateways per query set--just do this twice?  How should keys mix into this?  for now back off the dht proxies
    # so this assumes that your @num_simultaneous_gateway_requests_per_query is 'total that you'll want out per request' like a factor of the key split
    (@num_simultaneous_gateway_requests_per_query/@key_multiply_redundancy.to_f).ceil # ltodo analyze ceil
  end
  public
  # TODOR take out the error repeating from here!
  # or create some type of friendly wrapper for it or something. 
  # keep it raw :) 

  def get_array(key, round_id = 'round_random_' << rand(1000000).to_s, func_to_call_with_results_up_to_several_times = nil, extra_description = nil, key_split_to_request_all_simultaneously = nil, repeat_all_keys_this_many_times_arbitrarily = nil, &block)
    func_to_call_with_results_up_to_several_times ||= block || @default_return_proc
    assert func_to_call_with_results_up_to_several_times.class == Proc
    
    outgoing_get_proc = proc do |status, values_with_pm, round_id, key_used|
      got_get_values(status, values_with_pm, key_used, round_id, func_to_call_with_results_up_to_several_times)
    end
    
    error('you dont have enough gateways to request one key per gateway') unless @num_simultaneous_gateway_requests_per_query >= @key_multiply_redundancy
    
    repeat_all_keys_this_many_times_to_get_that_many_gateways = how_many_times_to_repeat_get_keys_to_different_gateways
    repeat_all_keys_this_many_times_to_get_that_many_gateways = repeat_all_keys_this_many_times_arbitrarily if repeat_all_keys_this_many_times_arbitrarily

    repeat_all_keys_this_many_times_to_get_that_many_gateways.times do |n|
      description = "request [#{key}] gws_no:#{n} #{extra_description}"
      do_multiple_keys_single_action key, round_id, description, 0, outgoing_get_proc, key_split_to_request_all_simultaneously do |conn, new_key_actually_used|
        existing_pm = @latest_place_markers[new_key_actually_used] ||= ''
        conn.get_single new_key_actually_used, existing_pm
      end
    end
  end
  
  def add(key, value, round_id = key + value.to_s + rand(1000000).to_s, description = '', block_proc = nil, retry_times = @retry_times_if_non_successful_answer, &block)
 # ltodo: allow retry_times for others, too
    block ||= block_proc || @default_return_proc
    description = "set [#{key} += #{value}] " << description
    do_multiple_keys_single_action(key, round_id, description, retry_times, block) { |conn, new_key|
      conn.add_value new_key, value
    }
  end

  create_named_parameters_wrapper :add
  
  def multiply_keys key, key_multiply_redundancy = @key_multiply_redundancy
    assert key_multiply_redundancy >= 1
    keys = [key] # starts with one already, so subtract one
    key_multiply_redundancy -= 1
    1.upto(key_multiply_redundancy) do |n| # make it 1 based so it's prettier :)
      keys << "#{key}-key_redundancy->#{n}"
    end
    keys
  end
  
  
  def got_get_values(status, values_with_pm, key, round_id, func_to_call_with_results_up_to_several_times)
    debug "maybe got values back: #{round_id} #{status} #{values_with_pm.inspect} (pm at end), old pm was #{@latest_place_markers[key].inspect}"
    pm_incoming = nil
    if status == :success
      pm_incoming = values_with_pm.pop
      if pm_incoming != @latest_place_markers[key]
        @latest_place_markers[key] = pm_incoming
        # ltodo the repeating version here get_array(key, func_to_call_with_results_up_to_several_times, round_id + '+', true, key_multiply_redundancy, num_simultaneous_gateway_requests_per_query)
        # ltodo pm's/gateway(/query)--that might for sure avoid any redundancy.  Not sure if this is a problem or not.
      else
        # debug "not calling again -- we got the same PM as was already there, so it was already called on before, even if not for us, I presume"
      end
    end
    func_to_call_with_results_up_to_several_times.call(status, values_with_pm, pm_incoming, round_id, key)
  end
  
  def done_and_clean?
    debug "length still open is #{@outstanding_conns_still_open.length} #{@outstanding_conns_still_open.inspect[0..300]}"
    return @outstanding_conns_still_open.empty?
  end
  
end

class ODHTTransport < EventMachine::Connection
  @@timeout_considered_error_in_seconds = 60   # these do timeout, too 120
  @@timeout_considered_error_in_seconds = TEST_TIMEOUT if Socket.gethostname == "Rogers-little-PowerBook.local" or Socket.gethostname == "melissa-pack"
  
  def ODHTTransport.setup(parent, description, round_id, key_new, all_the_way_out_proc)
    assert block_given?
    gw = parent.next_gateway
    host, port = gw[0], gw[1]
    
    message = "starting odht conn to [next gateway] #{host} #{port}"
    message << " -- will incur DNS!!!" unless host =~ /^[\d\.]+$/ or host == 'localhost' 
    parent.debug message 
    begin
      EM::connect(host, port, ODHTTransport) {|conn|
        conn.basic_host_init gw[0], gw[1], parent, description
        yield(conn, host, port)
      }
    rescue Exception => e
      parent.logger.error "SEEDO BAD! opendht erred in an odd way #{round_id} #{e.to_s + e.class.to_s} #{gw.inspect} #{e.backtrace.inspect}"
      all_the_way_out_proc.call(:failure, nil, round_id, key_new) if all_the_way_out_proc
    end
  end
  
  def log m
	@logger.log @log_prefix + m if @logger
  end

  def error m
	@logger.error @log_prefix + m if @logger
  end

  def debug m
	@logger.debug @log_prefix + m if @logger
  end

  def basic_host_init host, port, parent, description
    @host = host
    @port = port
    @parent = parent
    @logger = @parent.logger
    @log_prefix = "odht_trans:#{description} -> #{host}:#{port}"
    @start_time = Time.now
    @received_data_ever = false
    self.set_comm_inactivity_timeout @@timeout_considered_error_in_seconds 
  end
  
  def set_finalize_function proc_to_call_on_return # used
    raise unless proc_to_call_on_return.class == Proc
    @proc_to_call_with_results = proc_to_call_on_return # all should take status, results, key used
    assertEqual @proc_to_call_with_results.arity, 3
  end
  
  def rm key, value
    @key = key
    send_single_odht_string "<methodCall>
      <methodName>rm</methodName>
      <params>
      <param><value><base64>#{key.to_sha.to_base64}</base64></value></param>
      <param><value><base64>#{value.to_sha.to_base64}</base64></value></param>
      <param><value><string>SHA</string></value></param>
      <param><value><base64>#{@parent.secret.to_base64}</base64></value></param>
      <param><value><int>#{@parent.ttl}</int></value></param>
      <param><value>#{@parent.application}</value></param>
      </params>
      </methodCall>"
    @setup_return_values_proc = proc {|string| generic_parse(string) }
  end
  
  def generic_parse string
    # '<?xml version="1.0" encoding="ISO-8859-1"?>
    # <methodResponse>
    #     <params>
    #         <param><value><int>0</int></value></param>
    #     </params>
    # </methodResponse>
    # '
    if string =~ /<int>0/
      status = :success
    else
      status = :failure
    end
    @status = status
  end
  
  def get_parse(message)
    # 'Heres the DHTs template response: (get, not get details)'
    # '<?xml version="1.0" encoding="ISO-8859-1">
    # <methodResponse>
    #     <paramarams>
    #         <param><value><array><data>
    #             <value><array><data>
    #                 <value><base64>value1In641dm+92gI87Vy5ZABErgZJ7pbtfZ+G9ootASb8OSu142xXXvy/Aw06amd5O87wrF8gTetZQ==</base64></value>
    #             </data></array></value>
    #             <value><array><data>
    #                 <value><base64>value2In648LhGCeXxLFXdhauo1dm+92gI87Vy5ZABErgZJ7pbtfZ+G9ootASb8OSu142xXXvy/Aw06amd5O87wrF8gTetZQ==</base64></value>
    #             </data></array></value>
    #             <value><base64>PMPMPMAAPub+SbJ7AAAAB4c9Uau9icuBlvDvtokvlNaPzMLDW9mjT/gSAUXQFBomDTS2VurrSRkAF/AAAB</base64></value>
    #         </data></array></value></param>
    #     </params>
    # </methodResponse>'
    if message =~ /methodResponse/
      # the format is <array><subarrays><pm></array>
      # so the format is <array>(<array>.*</array>)*<value> -- however note that each interior is just a value (and there's always a last value--the pm)
      base_64_values_inside = message.split(/<.?base64>/).reject{|a| a.include? 'value'}
      values = []
      for base64 in base_64_values_inside do
        values << base64.from_base64
      end
      @status = :success
      @results_array = values # note the pm is included as the last value, and is no longer in base64!
    else
      @status = :failure
    end
  end
  
  def get_single key, pm
    @key = key
    send_single_odht_string "<?xml version='1.0'?> 
      <methodCall>
        <methodName>get</methodName>
        <params>
          <param><value><base64>#{key.to_sha.to_base64}</base64></value></param>
          <param><value><int>#{@parent.max_return_values}</int></value></param>
          <param><value><base64>#{pm.to_base64}</base64></value></param>
          <param><value><string>#{@parent.application}</string></value></param>
        </params>
      </methodCall>"
    @setup_return_values_proc = proc{ |string| get_parse(string) }
  end
  
  def send_single_odht_string string
    header = create_rpc_header string#, host, port
    send_data header
    send_data string
  end
  
  def add_value key_new, value
    @key = key_new # stinky @key!
    debug "adding #{key_new} -> #{value}"
    send_single_odht_string "<methodCall>
      <methodName>put_removable</methodName>
      <params>
      <param><value><base64>#{key_new.to_sha.to_base64}</base64></value></param>
      <param><value><base64>#{value.to_s.to_base64}</base64></value></param>
      <param><value><string>SHA</string></value></param>
      <param><value><base64>#{@parent.secret.to_sha.to_base64}</base64></value></param>
      <param><value><int>#{@parent.ttl}</int></value></param>
      <param><value><string>#{@parent.application}</string></value></param>
      </params>
      </methodCall>"
    @setup_return_values_proc = proc {|string| generic_parse(string) }
  end  
  
  def receive_data message # better match specs, or we are ignoring it! ltodo err or something
    assert @setup_return_values_proc
    @setup_return_values_proc.call(message)
    finalize
  end
  
  def finalize
    return if @already_finalized
    @already_finalized = true
    @status ||= :failure
    debug "post open dht completed #{@status} after #{Time.now - @start_time}s #{@host}:#{@port}" 
    close_connection # feeble effor to save on descriptors. ugh. ltodo helpful?
    @proc_to_call_with_results.call(@status, @results_array, @key)
  end
  
  def unbind
    error "unbind early" unless @already_finalized # don't report other error messages, as the logger might be done already!
    finalize
  end
  
  def connection_completed
    info = get_tcp_connection_info_hash rescue {}
    @log_prefix << " from #{info[:local_host]}:#{info[:local_port]} => #{info[:peer_host]}:#{info[:peer_port]}"
  end
  
  def create_rpc_header for_this_string # host, port
    #          assert host and port
    #Host: #{host}:#{port}\r\n
    "POST /RPC2 HTTP/1.0\r\nUser-Agent: roger_p2pwebclient:#{$version}\r\nContent-Type: text/xml\r\nContent-Length: %d\r\n\r\n" % for_this_string.length # ltodo get user-agent from same place
  end
  
end 


require 'base64'
class String
  def to_base64
    return Base64.encode64(self) # works with '', too, so with pm
  end
  def from_base64
    return Base64.decode64(self)
  end 
end
# stolen code :)
class String
  def to_sha
    d = Digest::SHA1.new
    d << self
    d.digest
  end
end
