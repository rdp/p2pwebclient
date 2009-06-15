#!/usr/bin/perl -w
#
# Copyright (c) 2001-2003 Regents of the University of California.
# All rights reserved.
#
# See the file LICENSE included in this distribution for details.
#
# Sean C. Rhea
# $Id: location-test-menu.pl,v 1.24 2004/11/30 05:36:20 sklower Exp $

use strict;

#if (! (defined $ENV{"OSTORE_RUN_DIR"})) {
    #die "You need to set OSTORE_RUN_DIR\n";
#}
#
#if (! (defined $ENV{"BAMBOO_TEST_DIR"})) {
    #die "You need to set BAMBOO_TEST_DIR\n";
#}

my @trash;
my $tmp_dir = "/tmp";

if ((defined $ENV{"OS"}) && ($ENV{OS} eq "Windows_NT")) {
	$tmp_dir = "C:\\cygwin\\tmp" ;
}

sub fork_process {
    my $log = shift( @_ );

    my $pid = fork();
    if( $pid > 0 ) {
	return $pid;
	
    } elsif( defined $pid ) {
	# child; run the named process..
	
	open STDOUT, ">$log" or &die( "can't redirect STDOUT");
	open STDERR, ">&STDOUT" or &die( "can't redirect STDERR");

	close STDIN;
	# now exec the process as specified.
	exec (@_);
    }
    
    # should never reach this point.
    &die( "fork failed" );
}

sub start_node {
    my ($gateway, $machine, $port) = @_;
    my $cfg = "$tmp_dir/experiment-$$-$machine-$port.cfg";
    my $log = "$tmp_dir/experiment-$$-$machine-$port.log";
    my $blocksdir = "$tmp_dir/experiment-$$-$machine-$port-blocks";
    push @trash, $log;
    push @trash, $cfg;
    push @trash, $blocksdir;

    print "Starting $machine:$port with gateway $gateway.\n";
    print "cfg=$cfg\n";
    print "log=$log\n";

    open (CFG_IN, "location-test-node.cfg") 
        or die "Could not open location-test-node.cfg";
    open (CFG_OUT, ">$cfg") or die "Could not open $cfg";

    my %variable_map = ("NodeID"      => "localhost:$port",
                        "GatewayID"   => $gateway,
                        "CacheDir"    => $blocksdir,
                        "GatewayPort" => ($port+2));

    while (<CFG_IN>) {
        if (m/\$\{([^}]+)\}/) {
            my $value = $variable_map{$1};
            if (defined $value) {
                s/\$\{([^}]+)\}/$value/;
            }
        }
        print CFG_OUT $_;
    }

    close (CFG_IN);
    close (CFG_OUT);

    my $pid = &fork_process ($log, # $ENV{"BAMBOO_TEST_DIR"} . 
            "../bin/run-java", "bamboo.lss.DustDevil", $cfg);

    print "pid=$pid\n";
    return $pid;
}

my $next_port = 3630;
my $node_count = 0;
my $gateway;
my @pids;

sub start_node_mi {
    if ($node_count == 0) {
	$gateway = "localhost:$next_port"; 
	push @pids, &start_node ($gateway, "localhost", $next_port);
    }
    else {
	push @pids, &start_node ($gateway, "localhost", $next_port);
    }
    $next_port += 3;
    ++$node_count;
}

sub stop_node_mi {
    if ($node_count > 0) {
	system ("kill " . (pop @pids));
	system ("rm -rf " . (pop @trash));
	system ("rm -rf " . (pop @trash));
	system ("rm -rf " . (pop @trash));
    }
    $next_port -= 3;
    --$node_count;
}

sub check_ptrs_mi {
    my @logs = ("$tmp_dir/experiment-$$*.log");
#    foreach (@pids) {
#	push @logs, "$tmp_dir/experiment-$_*.log";
#    }
    system ("cat @logs | ./check-obj-ptrs.pl | more");
}

sub check_node_status_mi {
    my @logs = ("$tmp_dir/experiment-$$*.log");
#    foreach (@pids) {
#	push @logs, "$tmp_dir/experiment-$_*.log";
#    }
    system ("grep 'Tapestry: ready' @logs");
}

sub check_for_errors {
    my @logs = ("$tmp_dir/experiment-$$*.log");
    system ("grep -i exception @logs");
}

sub quit_mi {
    while ($#pids >= 0) {
	system ("kill " . (shift @pids));
    }
    while ($#trash >= 0) {
	system ("rm -rf " . (shift @trash));
    }
    exit 1;
}

my @menu = ( 
    [\&check_node_status_mi, "Check node status"],
    [\&check_ptrs_mi,        "Check object pointers"],
    [\&check_for_errors,     "Check for exceptions"],
    [\&start_node_mi,        "Start a node"],
    [\&stop_node_mi,         "Stop a node"],
    [\&quit_mi,              "Quit"]
); 

my $last_choice = 4; # start a node
while (1) {
    my $i = 0;
    print "\nMenu:\n";
    while ($i <= $#menu) {
	printf "%5d.  %s\n", $i+1, ${$menu[$i]}[1];
	++$i;
    }
    print "Your choice: [$last_choice]  ";
    my $choice = <STDIN>;  chomp ($choice);
    print "\n";
    if ($choice =~m/^\s*$/) {
	&{${$menu[$last_choice-1]}[0]} (); 
    }
    elsif (($choice =~ m/^\s*(\d+)\s*$/) &&
	($1 >= 1) && ($1 - 1 <= $#menu)) {
        $last_choice = $choice;
	&{${$menu[$choice-1]}[0]} (); 
    }
    else {
	print "Bad choice.\n";
    }
}






