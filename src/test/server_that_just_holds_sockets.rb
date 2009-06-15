#require 'constants'
require 'rubygems'
require 'eventmachine'
EM.kqueue
EM::run {
     EventMachine::start_server '0.0.0.0', 9000
	print "started on 9000"
}
#require 'constants'
require 'rubygems'
require 'eventmachine'
	EM.kqueue
EM::run {
	print "pre kqueue"
	print "post kqueue"
	proc = proc{
		print '.'
		a = EM::connect('127.0.0.1', 9000)
#		EM::next_tick {proc.call}
	}
	EM::next_tick { proc.call} # start er off
 
}

