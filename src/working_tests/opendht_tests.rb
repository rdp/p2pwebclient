require 'constants'
require 'test/unit'
require 'eventmachine'
require 'lib/opendht/opendht_em'
require 'lib/opendht/opendht_em_fake.rb' # why not :)
EventMachine.fireSelfUp

module OpenDHT_Tests # don't run these, run _fake or _real!
  def setup
    EventMachine.fireSelfUp
  end
  
  def get_results_once(key)
    @round = rand(100000).to_s    
    @latest_results = nil
    @subject.get_array(key, @round, proc {|status, results, pm, round, key| set_last_results_once(status, results, @round)})
    sleep 0.1 while !@latest_results
    @latest_results
  end
  
  def set_last_results_once(status, results, round)
    print "got result! #{status} #{results}, #{round}"
    if round == @round
      @latest_status = status
      @latest_results = results
    else
      print 'ignoring one late!'
    end
  end
  
  def setup
    logger = Logger.new("test/test_opendht.txt", 100)
    @subject = get_right_class.new(logger, 1, 1, 10, 0)
    @sets_has_returned = proc { @has_returned = true } # useful
      #subject.gateways = [['localhost', 8082]]
  end
  
  def wait_for_has_returned
    sleep 0.05 while !@has_returned
  end
  
  def wait_for_first_return
    @has_returned = nil
    @subject.default_return_proc = @sets_has_returned # they can override this, if they want, but I guess they probably wouldn't want to if called with this function :)
    yield
    wait_for_has_returned  
  end

  def teardown
    
  end
 
  def test_gets_few
    logger = Logger.new("test/test_opendht.txt", 100)
    subject = get_right_class.new(logger, 2, 2, 10, 0)
    key = rand(10000000).to_s
    number = 0
    subject.add(key, 'few_val') {|*args|
     pp args
     number += 1
    }
    sleep 0.1 while number < 2 # only sets twice
    number_got = 0
    subject.get_array(key, 'round', proc {print "GOT ONE\n\n"; number_got += 1}, nil, 1, 1)
    sleep 7
    assert_equal 1, number_got
    
  end
 
  def test_setting_completes
    @subject.add('key','value')
    sleep 2
  end
 
  
  
  def test_setting_sets_many
    logger = Logger.new("test/test_opendht.txt", 100)
    @subject = get_right_class.new(logger, 5)  # 5 keys
    sum = 0
    @subject.add('key', 'value') { sum += 1}
    assert !@subject.done_and_clean?
    Timeout::timeout(5) {
      sleep 0.1 while sum < 5
    }
    assert @subject.done_and_clean?
  end
  
  
  def test_removing_does_not_fail
    @subject.remove('key', 'value')
    sleep 1
  end

  def test_get_does_not_fail
    @subject.get_array('not_set_yet_key', 'fake round', proc {})
  end
 
  def test_gets_empty
    print "requesting empty\n"
    @latest_status = nil
    assertEqual get_results_once('empty'), []
    assertEqual @latest_status, :success
  end 
  
  def test_set1_get1
    key = 'setting_key' + rand(1000000).to_s
    @subject.add(key,'value1')
    sleep 2
    assertEqual get_results_once(key), ['value1']
    assertEqual @latest_status, :success
  end
  
  def test_clears_out_outstanding_running_processes
   key = 'in then out' + rand(1000000).to_s
   wait_for_first_return{@subject.add(key, 'value')}
   wait_for_first_return{@subject.remove(key, 'value')}
   assert @subject.done_and_clean?
  end 
  
  def test_calculates_multiple_gateways
    logger = Logger.new("test/test_opendht_multiples.txt", 100)
    @subject = get_right_class.new(logger, 2, 2, 5, 15)
    sleep 0.5
    assert @subject.instance_variable_get(:@gateways).length > 1
    assert @subject.instance_variable_get(:@gateways)[0][0] != 'opendht.nyuld.net'
    
  end
  
  
  def test_set1_rm1
    key = 'key' + rand(1000000).to_s
    wait_for_first_return { @subject.add(key, 'value', key) }
      
    assertEqual get_results_once(key), ['value']
    wait_for_first_return {@subject.remove(key, 'value') }
    assertEqual get_results_once(key), []
  end
  
  def test_set2_rm1
    key = '2' + rand(1000000).to_s
    wait_for_first_return { @subject.add(key,'1') }
    wait_for_first_return { @subject.add(key,'2') }
    assertEqual get_results_once(key), ['1','2']
    assertEqual @latest_status, :success
    wait_for_first_return {@subject.remove(key,'2') }
    assertEqual get_results_once(key), ['1']
  end
  
  def test_get_many
    #  get 25 straight-- the one we can no longer do
  end
  
  def get15_or_less expected
    key = rand(1000000).to_s
    threads = []
    expected.times do |n|
      threads << Thread.new { @subject.add(key,n.to_s) } # no join => add mutex!
    end
    results = {}
    for thread in threads do thread.join end
    
    add_to_result = nil
    add_to_result = proc {
      @subject.get_array(key, 'fake round', proc {|status, some_results, pm, round, key| 
        for result in some_results
          # got some value
          results[result] = true
        end if some_results
        if results.length < expected
          add_to_result.call
        end
      })
    }
    add_to_result.call
    while results.length < expected
      print "got #{results.length}, need #{expected}\n"
      sleep 0.2
    end
    assertEqual results.length, expected # still haven't given us too many, though I guess it would be possible in a dht with churn (some delete, to it feeds us a few more), but not in a controlled environment. :)
  end
  
  def test_get_five
    get15_or_less 5
  end
  
  def test_get_nine
    get15_or_less 9
  end
  
  def test_get_by_nines
    key = rand(10000000).to_s
    25.times do |n|
      wait_for_first_return { @subject.add(key, n.to_s) }
    end
    # added them--now get 9
    results = {}
    add_in_proc = proc {|status, some_results, pm, round, key| 
      for result in some_results
        # a value
        results[result] = true
      end if some_results
    }
    @subject.get_array(key, 'random round 2', add_in_proc)
    sleep 0.1 while results.length < 9
    @subject.get_array(key, 'random round 2', add_in_proc)
    sleep 0.1 while results.length < 18
    @subject.get_array(key, 'random round 2', add_in_proc)
    sleep 0.1 while results.length < 25
    assert results.length == 25
    
  end
  
  def test_multiple_factored_response
    logger = Logger.new("test/test_opendht_multiples.txt", 100)
    @subject = get_right_class.new(logger, 2, 2, 5, 15) # lots-a them    
    sleep 2
    @subject.add('mutiple_key_test', 'fake_value')
    sleep 1
    assert get_multiple_results(@subject, 'multiple_key_test').length == @subject.total_get_responses_expected
  end
  
  def get_results dht_subject, key
      latest_results = nil
      latest_status = nil
      dht_subject.get_array(key, proc {|status, results, pm, round, key| latest_status = status; latest_results = results})
      sleep 0.1 while !latest_results and !latest_status
      latest_results
  end

  def get_multiple_results dht_subject, key
      latest_results = []
      latest_status = []
      num_expected_total = dht_subject.total_get_responses_expected
      dht_subject.get_array(key, 'fake round', proc {|status, results, pm, round, key|
          latest_status << status; 
          latest_results << results}
      )
      while latest_results.length < num_expected_total
        print "got #{latest_results.length}/#{num_expected_total}\n"
        sleep 1
      end
      latest_results
  end
  
end
