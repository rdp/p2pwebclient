#!/bin/bash
COUNTER=50
until [  $COUNTER -lt 10 ]; do
             echo COUNTER $COUNTER
             let COUNTER-=1
              # this could get big
             ruby listener.rb
#			 >> ../logs/`ruby -e "require 'lib/ruby_useful_here.rb'; print Socket.get_host_ip()"`/listenerStdOut.txt
             killall -9 ruby # my own
		killall -9 python
done
echo "done with 50 X listener!"
