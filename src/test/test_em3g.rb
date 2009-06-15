      require 'rubygems'
require 'constants'
      require 'eventmachine'
      module EchoServer

        def receive_data data
          send_data ">>>you sent: #{data}"
          print "server got #{data} #{@yo}\n"
          close_connection if data =~ /quit/i
        end
      
      def go_every_tick
                print 'n'
                EM::next_tick( Proc.new { go_every_tick() } ) # reschedule for the next_tick, you will go again
# here you could check outbound queue size, etc.
        end
        
        def post_init
          send_data "some stuff"
          print "outbound send is", get_outbound_data_size
          a = Proc.new { print 'n', next_tick(a) }
          go_every_tick
        end
      end

  module EchoClient
     def post_init
       print "post init client\n"
       send_data "client data_that_i_sent"
     end
     def receive_data data
       print "client got ", data, "\n"
      # send_data "quit"
     end
 end
# start it in its own thread
     em_thread = Thread.new {
       EventMachine::run {
        port = 8082
        EventMachine::start_server("127.0.0.1", port, EchoServer) { |conn|
        
        }
        EM.connect( '127.0.0.1', port, EchoClient) { |conn| print "client block conn: #{conn.inspect}\n"

	print "sockname [#{conn.get_sockname}] [#{conn.get_sockname.pretty_inspect}] #{conn.get_sockname.inspect}"
	require 'ruby-debug'
	a = conn.get_sockname
	Socket.unpack_sockaddr_in(a)
	print 'translated', Socket.unpack_sockaddr_in(conn.get_sockname).inspect
}
        EM.connect( '127.0.0.1', port, EchoClient) { |conn| print "client block conn: #{conn.inspect}\n"}
      }
     }
     sleep 2
sleep
