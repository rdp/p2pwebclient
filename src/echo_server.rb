      require 'constants'
$:.unshift  "lib/em/lib"
      $:.unshift '~/dev/p2pwebclient/src/ext/mac_os_x' if RUBY_PLATFORM =~ /darwin/
      require 'rubygems'
      require 'eventmachine'

      module EchoServer

        def receive_data data
          send_data ">>>you sent: #{data}"
          print "server got #{data} from #{data.inspect}\n"
          close_connection if data =~ /quit/i
        end
      
      end
# start it in its own thread
     em_thread = Thread.new {
       EventMachine::run {
        port = 3000
        EventMachine::start_server("0.0.0.0", port, EchoServer) { |conn|
        }
        print 'started on port', port, "\n"
      }
     }
     sleep

