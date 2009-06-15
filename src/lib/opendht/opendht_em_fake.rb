class OpenDHTEMFake
  @@all = {}
  @@failureLevel = 1 # 1 is no failure
  
  def initialize logger, key_multiply_redundancy = 1, num_simultaneous_gateways_per_query = 1, gateway_pool_size = 3, gateway_pool_creation_race_size = 3
    @logger = logger
    @key_multiply_redundancy = key_multiply_redundancy
    @num_simultaneous_gateways_per_query = num_simultaneous_gateways_per_query
    @gateways = ['http://opendht.nyuld.net:5851']
    if gateway_pool_size > 0
      @gateways = ['fakehost:5851']*gateway_pool_size
    end
    @original_gateways = @gateways.dup
    @already_open_conns = {}
    @gateways = @gateways*gateway_pool_size
    @place_markers = {} # key => pm, always assume latest is better.
    @func_to_call_when_empty_because_we_are_in_shutdown_mode = nil
    @log_prefix = "fakeopendhtem"
  end
  attr_accessor :func_to_call_when_empty_because_we_are_in_shutdown_mode
  include Logs
  def total_get_responses_expected
    return @key_multiply_redundancy * @num_simultaneous_gateways_per_query
  end
  
  def remove(key, value, round_id = 'fake_round', proc_in = nil, &block)
    proc_in = proc_in || block || @func_to_call_when_empty_because_we_are_in_shutdown_mode
    debug "deleting #{key} -> #{value}"
    if !@@all[key] or (@@all[key] and !@@all[key].include?(value))
      debug "warning asked for remove #{key} -> #{value} and not found" # servers will try and clean themselves up well. Hmm.
    else
      assert out = @@all[key].delete(value)# deletes it from the internal array.
      @@all.delete(key) if @@all[key].length == 0 # don't need to keep it around--clutters things
    end
    proc_in.call(:success, nil, round_id, key) if proc_in
  end
  
  def add(key, value, round_id = 'fake_round' + Time.new.to_s, proc_in = nil, &block)
    proc_in = proc_in || block || @func_to_call_when_empty_because_we_are_in_shutdown_mode
    value = value.to_s
    debug "adding (instantaneously) #{key} -> #{value}"
    if @@all[key]
      @@all[key] = @@all[key] << value
    else
      @@all[key] = [value] # add it as an array
    end
    proc_in.call(:success, nil, round_id, key) if proc_in
  end
  
  def OpenDHTEMFake.setFailureLevel to_this
    @@failureLevel = to_this
  end
  @@count_to_fail = 0
  
  def get_array(key, round_id = 'fake round get', func_to_call_with_results_up_to_several_times = nil, &block)
    func_to_call_with_results_up_to_several_times ||= block || @func_to_call_when_empty_because_we_are_in_shutdown_mode
    get_all_not_just_9 = false # for now, permanently :) 
    # if there is a pm, always go from there
    existing_pm = @place_markers[key] || 0 # for me it will be...a numbered index.  It could really be for them, too!
    gw = 'fake_gw'
    @already_open_conns[key + round_id.to_s + gw] = EM::Timer.new(0.4){
      total_get_responses_expected.times do
        debug "returning your key #{key}}"
        state = rand(@@failureLevel)
        if @@count_to_fail > 0
          @@count_fail -= 1
          state = 1 # forced failure
        end
        if state == 0
          debug "with success"
          if @@all[key]
            assert @@all[key].length > 0, " I thought I deleted blank ones!"
            if get_all_not_just_9
              output = @@all[key][existing_pm..-1]
              @place_markers[key] = [@@all[key].length - 4, 0].max # how about 4 back?
            else
              output = @@all[key][existing_pm..(existing_pm+8)]
              @place_markers[key] = [[existing_pm+9, @@all[key].length - 4].min, 0].max # pm is always gross and behind
            end
            output ||= []
          else
            output = []
          end
          func_to_call_with_results_up_to_several_times.call(:success, output, round_id, key)
        else
          debug "with failure"
          func_to_call_with_results_up_to_several_times.call(:failure, nil, round_id, key)  
        end
      end
      @already_open_conns.delete(key + round_id.to_s + gw)
    }
  end
  
  def done_and_clean?
    return @already_open_conns.empty?
  end
  
end

