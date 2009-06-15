#!/usr/bin/perl -w
# 
# $Id: get-failures-by-host.pl,v 1.1 2004/05/12 03:25:09 srhea Exp $
#
use strict;
my $logdir = "/home/srhea/openhash-logs";

my $startstr = $ARGV[0];
my $endstr = $ARGV[1];

my $starttime = `date -d '$startstr' +\%s`;
my $endtime = `date -d '$endstr' +\%s`;
chomp ($starttime);
chomp ($endtime);

my $tmpfile = "/tmp/get-failures-by-host-$$";

system ("find $logdir/ -name '*.getfail' | xargs cat | awk '{if (\$1 >= $starttime && \$1 <= $endtime) print;}' > $tmpfile");

my %host;
open (FILE, $tmpfile);
while (<FILE>) {
    if (m/^\d+\s+(.*)$/) {
        if (! (defined $host{$1})) {
            $host{$1} = 1;
        }
        else {
            $host{$1} += 1;
        }
    }
}

unlink $tmpfile;

my $h;
foreach $h (keys %host) {
    print "$h " . $host{$h} . "\n";
}
    
