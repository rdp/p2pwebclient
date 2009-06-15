#!/usr/bin/perl -w
#
# Copyright (c) 2001-2003 Regents of the University of California.
# All rights reserved.
#
# See the file LICENSE included in this distribution for details.

use strict;

while (<STDIN>) {
    if (m/(\d+\.\d+) (\d+\.\d+\.\d+\.\d+).* client (\d+\.\d+\.\d+\.\d+) usage now ([0-9.]+) (\w+) of ([0-9.]+) (\w+) total/) {
        my ($time, $server, $client, $ccnt, $cunit, $tcnt, $tunit) = 
            ($1, $2, $3, $4, $5, $6, $7);
        if ($cunit eq "KBs") { $ccnt *= 1024; }
        if ($tunit eq "KBs") { $tcnt *= 1024; }
        if ($cunit eq "MBs") { $ccnt *= 1024*1024; }
        if ($tunit eq "MBs") { $tcnt *= 1024*1024; }
        if ($cunit eq "GBs") { $ccnt *= 1024*1024*1024; }
        if ($tunit eq "GBs") { $tcnt *= 1024*1024*1024; }
        printf "$time $server $client $ccnt $tcnt %0.1f\n", $ccnt/$tcnt*100;
    }
}

