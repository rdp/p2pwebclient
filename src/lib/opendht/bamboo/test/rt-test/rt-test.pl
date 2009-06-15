#!/usr/bin/perl -w
# 
# $Id: rt-test.pl,v 1.3 2003/09/15 05:25:27 srhea Exp $
#
use strict;
use Statistics::Descriptive;

my @counts;
my @holes;
my @lsonly;
my @ineff;

while (<STDIN>) {
    if (m/RT Test \| level (\d+) hole:/) {
        ++$counts[$1];
        ++$holes[$1];
    }
    elsif (m/RT Test \| level (\d+) inefficient:.*at ([0-9.]+).*at ([0-9.]+)/) {
        ++$counts[$1];
        if (! (defined $ineff[$1])) {
            my @empty = ();
            $ineff[$1] = \@empty;
        }
        my $aryref = $ineff[$1];
        push @$aryref, $3/$2;
    }
    elsif (m/RT Test \| level (\d+) good:.*leaf set only/) {
        ++$counts[$1];
        ++$lsonly[$1];
    }
    elsif (m/RT Test \| level (\d+) good:/) {
        ++$counts[$1];
    }
}

for (my $i = 0; $i <= $#counts; ++$i) {
    print "LEVEL $i  $counts[$i] total RT entries\n";
    if (defined $holes[$i]) {
        print "LEVEL $i  $holes[$i] total holes cannot be filled using leaf set\n";
        printf "LEVEL $i  %f percent of fillable rt entries are holes\n",
            $holes[$i]/$counts[$i]*100.0;
    }
    else {
        $holes[$i] = 0;
    }
    if (defined $lsonly[$i]) {
        print "  $lsonly[$i] total holes can be filled using leaf set\n";
    }
    if (defined $ineff[$i]) {
        my $stat = Statistics::Descriptive::Full->new();
        $stat->add_data (@{$ineff[$i]});
        print "LEVEL $i  " . $stat->count () . " total inefficient entries\n";
        print "LEVEL $i  " . $stat->mean () . " average inefficiency\n";
        print "LEVEL $i  " . ($counts[$i]-$holes[$i]-$stat->count () 
                + $stat->count ()*$stat->mean ())/($counts[$i]-$holes[$i]) . 
                " overall average inefficiency\n";
    }
}

my $total_entries = 0;
my $total_holes = 0;

for (my $i = 0; $i <= $#counts; ++$i) {
    $total_entries += $counts[$i];
    if (defined $holes[$i]) {
        $total_holes += $holes[$i];
    }
}

printf "%f percent of all holes unfilled\n", $total_holes/$total_entries*100;

