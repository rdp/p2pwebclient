require 'socket'
require 'rubygems'
require 'eventmachine'
require 'event_machine_addons'
require 'parse_tree'
require 'create_named_parameters_wrapper.rb'
require 'enhanced_arg_parser.rb'
require 'opendht_em.rb'

# some unfortunate dependencies opendht_em has

def assert bool, message = 'assertion failed'
  raise message unless bool
end

def assertEqual val1, val2, message = 'nope'
  raise message unless val1 == val2
end

def Y 
  lambda { |f| f.call(f) }.call( 
    lambda do |g| 
      yield(lambda { |*n| g.call(g).call(*n) }) 
    end) 
end 
 
#print Y { |this| lambda { |n| n == 0 ? 1 : n * this.call(n - 1) } }.call(12) #=> 479001600

EventMachine.run { 
   @opendht = OpenDHTEM.new(nil, 1, 1, :gateway_pool_size => 250, :gateway_pool_creation_race_size => 250)
   count = 0
   procy =  proc {
   	@opendht.add( 'key', 'value') { print "add returned!\n" } # all go to same host, really
	count += 1
	EM::next_tick &procy if count < 100_000
	print "done!\n" if count == 100_000
   } 
   EM::Timer.new(5) { procy.call }

   EM::Timer.new(1) {  # start this after one second
	print "doing get"
	@opendht.get_array('key') {|status, values, pm, round, key_used| print "got back #{values.inspect} -- ctrl+c to end\n" } 
   }
   print "sent request--waiting one second then doing get\n"
}
