#!/bin/sh

if ps uxww | grep java | grep -q irb-putget 
then
    echo PutGetTest already running.
else
    echo Starting PutGetTest.
    nohup /home/srhea/bamboo/bin/run-java -mx128M bamboo.lss.DustDevil -l /home/srhea/bamboo/planetlab/irb-putget.lcfg /home/srhea/bamboo/planetlab/irb-putget.cfg >& /home/srhea/putget-logs/irb-not-logged < /dev/null &
fi

