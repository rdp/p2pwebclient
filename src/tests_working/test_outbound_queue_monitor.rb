      
      $:.unshift "../lib"
      require 'eventmachine'
      require 'test/unit'
      
      class TestNextTick < Test::Unit::TestCase
      
def setup
        def assure_em_started
          if !EM::reactor_running?
               @running_em_thread = Thread.new { EM::run {} }
          end
        end
        assure_em_started


end
def teardown
  EM::stop if EM::reactor_running?
  @running_em_thread.join if @running_em_thread
end
      module EchoServer

        def receive_data data
          #send_data ">>>you sent: #{data}"
          #print "server got #{data} #{@yo}\n"
          print '.'
          close_connection if data =~ /quit/i
        end
        def post_init
          print "post init server\n"
        end
      end

  module EchoClient
     def post_init
       
     end
     def receive_data data
       print "client got ", data, "\n"
       #send_data "quit"
     end
 end


def test_quantum
        old_quantum = EM::get_timer_quantum
        EM::set_timer_quantum(old_quantum - 1)
        new_quantum = EM::get_timer_quantum
        assert_not_equal new_quantum, old_quantum
end

def test_outbound_queue
      
        port = 8082
        print "listtening #{port}"
        EventMachine::start_server("127.0.0.1", port, EchoServer) { |conn|
                print "server block conn: #{conn.inspect}\n"
        }

       count = 0
        EM.connect( '127.0.0.1', port, EchoClient) { |conn| 
         send_proc= proc { |wrapper_class|
          print 'sending', "\n"
          send_data 'a'
          count += 1
         }
         queued_proc = conn.create_proc_that_runs_only_when_outbound_queue_gets_below(0.0, send_proc)
         EventMachine::PeriodicTimer.new(0.1, queued_proc)

         Thread.new { sleep 1.1
           assert count < 10
           EM::stop
         }
        }

        end
        def test_more_frequent_queue
        port = 8082
        count = 0


        EventMachine::start_server("127.0.0.1", port, EchoServer) { |conn|
                print "server block conn: #{conn.inspect}\n"
        }

        EM.connect( '127.0.0.1', port, EchoClient) { |conn| 
                                       
         send_proc= proc { |wrapper_class|
          print 'sending', "\n"
          count += 1
         }
         queued_proc = conn.create_proc_that_runs_only_when_outbound_queue_gets_below(1000000, send_proc)
         EventMachine::PeriodicTimer.new(0.05, queued_proc)

        }
         sleep 0.30
          
         assert count >4 

        end

        def test_big_outbound_queue
        port = 8082
        EventMachine::start_server("127.0.0.1", port, EchoServer) { |conn|
                print "server block conn: #{conn.inspect}\n"
        }

       count = 0
        EM.connect( '127.0.0.1', port, EchoClient) { |conn| 
         send_proc= proc { |wrapper_class|
          print 'sending', "\n"
          conn.send_data 'a'*10000000 # this shouldn't run often!
          count += 1
         }
         queued_proc = conn.create_proc_that_runs_only_when_outbound_queue_gets_below(100_000, send_proc)
         EventMachine::PeriodicTimer.new(0.1, queued_proc)

        }
         sleep 0.25
         assert count < 10
        end

end
