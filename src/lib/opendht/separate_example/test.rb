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

EventMachine.run { 
   @opendht = OpenDHTEM.new(nil)
   @opendht.add( 'key', 'value') { print "add returned!\n" }
   EM::Timer.new(1) {  # start this after one second
	print "doing get"
	@opendht.get_array('key') {|status, values, pm, round, key_used| print "got back #{values.inspect} -- ctrl+c to end\n" } 
   }
   print "sent request--waiting one second then doing get\n"
}
