#!/usr/bin/perl -w
# 
# $Id: stretch.pl,v 1.2 2003/09/15 05:25:51 srhea Exp $
#
use strict;
use Statistics::Descriptive;

my $bucket_width = $ARGV[0];
my @bucket_values;

while (<STDIN>) {
    if (m/^STRETCH (\d+) (\d+) (\d+)$/) {
        if ($3 != 0) {
            my $bucket = int ($1 / $bucket_width);
            my $stretch = $2/$3;
            my $aryref;
            if (defined $bucket_values[$bucket]) {
                $aryref = $bucket_values[$bucket];
            }
            else {
                my @ary = ();
                $aryref = \@ary;
                $bucket_values[$bucket] = $aryref;
            }
            #print STDERR "$bucket\t$stretch\n";
            push @$aryref, $stretch;
        }
    }
}

for (my $i = 0; $i <= $#bucket_values; ++$i) {
    my $time = $i * $bucket_width;
    my $aryref = $bucket_values[$i];
    if ($#$aryref >= 0) {
        my $stat = Statistics::Descriptive::Full->new();
        $stat->add_data (@$aryref);
        printf "$time\t%d\t%5.2f\t", $stat->count (), 
            $stat->percentile(5);

        # For some reason, the first call to percentile messes up subsequent
        # ones.

        $stat = Statistics::Descriptive::Full->new();
        $stat->add_data (@$aryref);
        printf "%5.2f\t", $stat->median ();

        $stat = Statistics::Descriptive::Full->new();
        $stat->add_data (@$aryref);
        printf "%5.2f\t", $stat->percentile(95);

        $stat = Statistics::Descriptive::Full->new();
        $stat->add_data (@$aryref);
        printf "%5.2f\t", $stat->mean ();

        $stat = Statistics::Descriptive::Full->new();
        $stat->add_data (@$aryref);
        printf "%5.2f\n", $stat->max ();
    }
}

