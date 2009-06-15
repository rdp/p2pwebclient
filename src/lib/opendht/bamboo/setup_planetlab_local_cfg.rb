require 'erb'
require '../../ruby_useful_here'
name = "cfg/openhash_second_planetlab_local.cfg"
node_number = 1
port1 = 3630 + 1
require 'known_gateways'
gateways = $opendht_gateways

am_gateway = false
if gateways[Socket.get_host_ip] 
 # you are a gateway!
 name = 'openhash_gateway_utah_generated.cfg'
 port1 = gateways[Socket.get_host_ip]
 am_gateway = true
end

gateways.each_key{|k|
 gateways[k] += 0
}
require 'pp'
pp 'gateways are', gateways
a = File.open name, 'w'
a.write ERB.new(File.read('openhash_generic.erb')).result(binding)
a.close
print 'wrote to ', name, "\n"

