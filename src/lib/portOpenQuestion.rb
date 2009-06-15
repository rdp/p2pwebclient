require 'lib/ruby_useful_here'
raise 'paramas are host, port, like 0.0.0.0 3000' unless ARGV.length == 2
begin
Timeout::timeout(5) {
  if TCPServer.new ARGV[0], ARGV[1].to_i
     print "open/available!"
  else
     print "closed!"
  end
}
rescue Timeout::Error
 print "timed out!"
end
