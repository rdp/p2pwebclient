      require 'rubygems'
      require 'eventmachine'

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
       EM::set_timer_quantum(5)
       run_when_outbound_queue_gets_below(3, 0.001, nil) {
          print 'sending', "\n"
          send_data 'some more stuff for you!'*1000000 
       }
       require 'ruby-debug'
       debugger
       print 3
     end
     def receive_data data
       print "client got ", data, "\n"
       #send_data "quit"
     end
 end


 EventMachine::run {
        port = 8082
        print "listtening #{port}"
        EventMachine::start_server("127.0.0.1", port, EchoServer) { |conn|
                print "server block conn: #{conn.inspect}\n"
        }
        EM.connect( '127.0.0.1', port, EchoClient) { |conn| print "client block conn: #{conn.inspect}\n"}
 }

