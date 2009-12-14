#!/bin/bash
if ! /home/srhea/bamboo/bin/run-java bamboo.lss.DustDevil /home/srhea/bamboo/planetlab/availability.cfg >& /tmp/avail-$$.out
then 
    echo Availability script failed.  Log follows:
    cat /tmp/avail-$$.out
    rm /tmp/avail-$$.out
    /usr/sbin/logrotate -s /home/srhea/openhash-availability/logrotate.state /home/srhea/bamboo/planetlab/availability.logrotate
    exit 1
else 
    rm /tmp/avail-$$.out
    exec /usr/sbin/logrotate -s /home/srhea/openhash-availability/logrotate.state /home/srhea/bamboo/planetlab/availability.logrotate
fi
