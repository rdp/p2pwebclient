#!/bin/bash
ps uxww > /tmp/availtestgets-$$.ps
if grep -q 'java.*availtestgets' /tmp/availtestgets-$$.ps
then
    echo Already running
    rm /tmp/availtestgets-$$.ps
    exit 1;
fi

rm /tmp/availtestgets-$$.ps
if ! /home/srhea/bamboo/bin/run-java bamboo.lss.DustDevil /home/srhea/bamboo/planetlab/availtestgets.cfg >& /tmp/availtestgets-$$.out
then 
    echo Availability script failed.  Log follows:
    cat /tmp/availtestgets-$$.out
    rm /tmp/availtestgets-$$.out
    /usr/sbin/logrotate -s /home/srhea/openhash-logs/availtest/logrotate.state /home/srhea/bamboo/planetlab/availtestgets.logrotate
    exit 1
else 
    rm /tmp/availtestgets-$$.out
    exec /usr/sbin/logrotate -s /home/srhea/openhash-logs/availtest/logrotate.state /home/srhea/bamboo/planetlab/availtestgets.logrotate
fi
