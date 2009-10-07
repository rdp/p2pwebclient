$: << "../lib"
require 'eventmachine'
    class Echo < EventMachine::Connection
     def initialize(*args)
      super
      # stuff here...
      @count = 0
     end

     def post_init
       send_data 'hello'
     end
     
     def receive_data(data)
      send_data data
      @count+= 1
     end

     def unbind
      puts 'back and forth messages in 1s:', @count
     end
    end


 module EchoServer
   def post_init
     puts "-- someone connected to the echo server!"
   end

   def receive_data data
     send_data data
   end

 end

 EventMachine::run {
   EventMachine::start_server "127.0.0.1", 8081, EchoServer
   EventMachine::connect '127.0.0.1', 8081, Echo
   EM::Timer.new(1) { EM.stop }
 }