#!/bin/sh

if ps uxww | grep java | grep -q irb-oh-hosts
then
    echo ProbeDaemon already running.
else
    echo Starting ProbeDaemon.
    nohup /home/srhea/bamboo/bin/run-java bamboo.www.ProbeDaemon /home/srhea/bamboo/planetlab/irb-oh-hosts 600 /home/srhea/bamboo/planetlab/irb-oh-probe.lcfg >& /home/srhea/putget-logs/irb-oh-probe-not-logged < /dev/null &
fi

