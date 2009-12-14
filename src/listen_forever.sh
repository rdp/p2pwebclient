#!/bin/bash
COUNTER=500
until [  $COUNTER -lt 10 ]; do
             echo COUNTER $COUNTER
             let COUNTER-=1
              # this could get big
             ruby listener.rb >> ../logs/`ruby -e "require 'lib/ruby_useful_here.rb'; print Socket.get_host_ip()"`/listenerStdOut`ruby -e 'p (rand()*10000).ceil'`.txt 2>&1
             killall -9 ruby # my own, sniff
		killall -9 python
done
echo "done with 500 X listener!"
