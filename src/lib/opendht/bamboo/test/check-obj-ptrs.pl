#!/usr/bin/perl -w
use strict;

my $current_ptr_list = [];
my $current_node;
my $reading_ptr_list = 0;
my %ptr_lists;
my %node_guids;

my $current_leaf_set = [];
my $reading_leaf_set = 0;
my $mid = 0;
my %leaf_sets;

while (<STDIN>) {
    if (m/Bamboo node ([^:]+:\d+) has guid 0x([\dA-Fa-f]+)/) {
        $current_node = $1;
	$current_node =~ s/localhost/127.0.0.1/;
        $node_guids{$2} = $current_node;
    }
    if ($reading_ptr_list) {
	if (m/^\s+(0x[0-9a-f]+)\s+(0x[\da-fA-F]+)\s*$/) {
	    push @$current_ptr_list, [$1, $2];
	}
	elsif (m/^range = /) {
	    # ignore it
	}
	else {
	    $ptr_lists{$current_node} = $current_ptr_list;
	    $reading_ptr_list = 0;
	    $current_ptr_list = [];
	}
    }
    if (m/DataManagerTest-([^:]+:\d+) stored data:$/) {
	$reading_ptr_list = 1;
	$current_node = $1;
	$current_node =~ s/localhost/127.0.0.1/;
    }
}

if ($reading_ptr_list) {
    $ptr_lists{$current_node} = $current_ptr_list;
}
if ($reading_leaf_set) {
    $leaf_sets{$current_node} = $current_leaf_set;
}

my ($key, $guid);
my %counts;
foreach $guid (sort keys %node_guids) {
    $key = $node_guids{$guid};
    $current_ptr_list = $ptr_lists{$key};

#    if (! (defined $leaf_sets{$key})) {
#	die "no leaf set for $key\n";
#    }
#    $current_leaf_set = $leaf_sets{$key};
#    if ($#{$current_leaf_set} < 0) {
#	die "empty leaf set for $key\n";
#    }
#    print "$key: ${$$current_leaf_set[0]}[3] to " . 
#	${$$current_leaf_set[$#{$current_leaf_set}]}[3] . "\n";

    print "$key, 0x$guid is storing\n";
    for (my $i = 0; $i <= $#{$current_ptr_list}; ++$i) {
	my $aryref = $$current_ptr_list[$i];
	my $k2 = "@$aryref";
	if (! (defined $counts{$k2})) {
	    $counts{$k2} = 1;
	}
	else {
	    $counts{$k2} += 1;
	}
	print "  @$aryref\n";
    }
    print "\n";
}

my $error = 0;
my @node_names = keys %ptr_lists;
my $exp_ptrs = 4;

foreach $key (sort keys %counts) {
    print "$key $counts{$key}";
    if (($counts{$key} < $exp_ptrs) && ($counts{$key} < $#node_names + 1)) {
	$error = 1;
	print " ---";
    }
    if (($counts{$key} > $exp_ptrs) || ($counts{$key} > $#node_names + 1)) {
	$error = 1;
	print " +++";
    }
    print "\n";
}

if ($error) {
    print "\nSome objects had bad counts.\n";
}
else {
    print "\nAll counts okay.\n";
}
