# $Id: test_running.rb 493 2007-08-13 20:10:46Z blackhedd $

# Author:: Francis Cianfrocca (gmail: blackhedd)
# Homepage::  http://rubyeventmachine.com
# Date:: 8 April 2006
# 
# See EventMachine and EventMachine::Connection for documentation and
# usage examples.
#
#----------------------------------------------------------------------------
#
# Copyright (C) 2006-07 by Francis Cianfrocca. All Rights Reserved.
# Gmail: blackhedd
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of either: 1) the GNU General Public License
# as published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version; or 2) Ruby's License.
# 
# See the file COPYING for complete licensing information.
#
#---------------------------------------------------------------------------
#
#
# 

$:.unshift "../lib"
require 'constants'
require 'eventmachine'

class Echoer < EM::Connection
  def post_init
	print 'post init on conn'
  end
  def receive_data m
	send_data m
  end
  

end

class SenderCheckerAndCaller < EM::Connection
	def send_and_receive_cycle string_to_send, proc_to_call_if_successfully_returns
	 @received_send_request = true
	 @string_sent = string_to_send
	 @return_proc = proc_to_call_if_successfully_returns
	 send_data string_to_send
	end

	def receive_data received
	 if received != @string_sent
		print 'arr! echoed wrong string!'
		raise
	 else
	   @return_proc.call
         end
        end

	def setup_early_unbind proc_to_call_on_early_unbind
		@proc_to_call_on_early_unbind = proc_to_call_on_early_unbind
	end

	def unbind
		if !@proc_to_call_on_early_unbind
			print "arr no unbind proc!!!"
		end
		@proc_to_call_on_early_unbind.call unless @received_send_request
	end
end

require 'test/unit'

class TestSocketCounts < Test::Unit::TestCase
	def setup # TODO right now these have to be run one at a time -- we need a suite
	end
	
	def teardown
		EM.stop if EM::reactor_running?
		sleep 0.1 while EM::reactor_running?
	end

       def many_descriptors
    		100.downto(1) do |n|
      			if EventMachine.set_descriptor_table_size(n*1000) == n*1000
        			print n*1000, 'descriptors given! run sudo for possibly more!'
        			break
      			end
    		end
	end

	def test_select # needs to be run first or by itself, or it will have lots of descriptors possibly
		create_many_sockets
	end

	def test_epoll
		EM.epoll
		create_many_sockets
	end

	def test_select_lots_of_descriptors
		print "many descriptors!\n"
		many_descriptors
		create_many_sockets
	end

	def test_kqueue
		many_descriptors
		EM.kqueue
		create_many_sockets
	end
	
	def create_many_sockets
		# for this one, let's fire up all the sockets we can, then send something to each of them--the count should go up
		# todo throw some file descriptors in there, too, and some popen process, why not?
		# another test would be to have two processes, so you could test 'just server' and 'just client-side'
		# todo do this with some udp too (kinder lower priority, as UDP isn't as commonly used)
		all_connections = []
		server_port = 2051 + rand(1000)
		Thread.new {
			EM.run {
				EM::start_server '0.0.0.0', server_port, Echoer
			}
		}
		sleep 0
		count_unbound_early = 0
		has_hit_error = false
		while(!has_hit_error)
			starting_size = all_connections.length
			EM::next_tick {
				begin
					print "making new conn\n"
					EM::connect( '127.0.0.1', server_port, SenderCheckerAndCaller ) { |conn|
						all_connections << conn	
						print "count #{all_connections.length}\n"
						conn.setup_early_unbind proc { count_unbound_early += 1}
			 		}
				rescue RuntimeError
					print "ok stopping their creation!\n"
					has_hit_error = true # assume out of descriptors or slots for select or something
				end
			}
			sleep 0.01 while all_connections.length == starting_size and (has_hit_error==false) # let next tick finish
			print "firing next conn\n"
		end
		sleep 0.3 # let unbind's happen if they should
		counter = 0	
		for connection in all_connections
			connection.send_and_receive_cycle rand(1000000).to_s, proc {counter += 1}
		end
	        sleep 1 # could make this a timeout or what not, I suppose				
		print "asserting\n"
		assert_equal( all_connections.length - count_unbound_early, counter  )
		for conn in all_connections
			conn.close_connection
		end
	end
end

