#!/usr/bin/perl -w
#
# Copyright (c) 2001-2003 Regents of the University of California.
# All rights reserved.
#
# See the file LICENSE included in this distribution for details.

use strict;


my $node_count = 100;
my $client_count = 100;
my $seed = 1;
my $end_time = 10*60*1000;
my $client_start_time = 3*60*1000;

srand $seed;

open (EXP, ">/tmp/gateway-test.exp") or die;

my $pwd = `pwd`;
chomp $pwd;
print EXP "bamboo.sim.KingNetworkModel $pwd/../src/bamboo/sim/king128.top\n";

my $port = 3660;
my @ips;
my %ipset;
for (my $i = 1; $i <= $node_count; ++$i) {
    my $ip;
    while (1) {
        my $graph_index = int (rand () * 128) + 1;
        $ip = "10.0.0.$graph_index";
        if (! (defined $ipset{$ip})) {
            $ips[$i] = $ip;
            $ipset{$ip} = $ip;
            last;
        }
    }
    my $gateway;
    if ($i == 1) {
        $gateway = 1;
    }
    else {
        $gateway = int (rand () * ($i-1)) + 1;
    }
    my $gateway_ip = $ips[$gateway];
    my $cfg = "/tmp/node-$i.cfg";
    printf EXP "$ip:$port\t%19s %8d %10d\n", $cfg, $i*1000, $end_time;
    open (CFG, ">$cfg");
    print CFG<<EOF;
<sandstorm>
    <global>
	<initargs>
EOF
    print CFG "	    node_id $ip:$port\n";
    print CFG<<EOF;
	</initargs>
    </global>

    <stages>
	<Router>
	    class bamboo.router.Router
	    <initargs>
EOF
    print CFG "		gateway $gateway_ip:$port\n";
    print CFG<<EOF;
                debug_level 0
	    </initargs>
	</Router>

        <DataManager>
            class bamboo.dmgr.DataManager
            <initargs>
                debug_level           0
                merkle_tree_expansion 2
            </initargs>
        </DataManager>

        <StorageManager>
            class bamboo.db.StorageManager
            <initargs>
                debug_level           0
EOF
    print CFG "                homedir               /tmp/gateway-blocks-$i\n";
    print CFG<<EOF;
            </initargs>
        </StorageManager>

        <Dht>
            class bamboo.dht.Dht
            <initargs>
                storage_manager_stage StorageManager
            </initargs>
        </Dht>

        <Gateway>
            class bamboo.dht.Gateway
            <initargs>
                port        3662
                debug_level 0
            </initargs>
        </Gateway>

        <Vivaldi>
            class bamboo.vivaldi.Vivaldi
            <initargs>
              vc_type          2.5d
              generate_pings   true
              eavesdrop_pings  false
              use_reverse_ping true
              ping_period      10000
              version          1
            </initargs>
        </Vivaldi>
    </stages>
</sandstorm>
EOF
    close (CFG);
}

$port = 3660;
for (my $i = 1; $i <= $client_count; ++$i) {
    $port += 10;
    my @possible_gateways = keys %ipset;
    my $which = int (rand ($#possible_gateways+1));
    my $ip = $possible_gateways[$which];
    my $cfg = "/tmp/client-$i.cfg";
    printf EXP "$ip:$port\t%19s %8d %10d\n", $cfg, 
                $client_start_time, $end_time;
    open (CFG, ">$cfg");
    print CFG<<EOF;
<sandstorm>
    <global>
        <initargs>
EOF
    print CFG "            node_id $ip:$port\n";
    print CFG<<EOF;
        </initargs>
    </global>

    <stages>
        <GatewayClient>
            class bamboo.dht.GatewayClient
            <initargs>
                debug_level             0
EOF
    print CFG "            gateway $ip:3662\n";
    print CFG<<EOF;
            </initargs>
        </GatewayClient>

        <GatewayClientTest>
            class bamboo.dht.GatewayClientTest
            <initargs>
                debug_level             0
EOF
    print CFG "            seed $i\n";
    print CFG<<EOF;
                client_stage_name       GatewayClient
            </initargs>
        </GatewayClientTest>
    </stages>
</sandstorm>
EOF
    close (CFG);
}

close (EXP);

