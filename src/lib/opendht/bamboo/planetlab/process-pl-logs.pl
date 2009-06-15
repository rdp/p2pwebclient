#!/usr/bin/perl -w
# 
# $Id: process-pl-logs.pl,v 1.2 2004/05/12 03:24:51 srhea Exp $
#
use strict;
my $logdir = "/home/srhea/openhash-logs";

my $list = `find $logdir/ -name '*.log'`;
my @logs = split /\s+/, $list;

sub munge_date {
   my $tz = shift;
   my $line = shift;
   if ($line =~ m/^(\d\d\d\d-\d\d-\d\d \d\d:\d\d):\d\d,\d\d\d/) {
       my $orig = $1;
       my $new = `date -d '$orig $tz' +%s`;
       chomp ($new);
       return $new;
   }
   else {
       return undef;
   }
}

sub munge_tz {
    my $log = shift;
    if ($log =~ m/latest.log/) {
        $log =~ s/latest\.log/timezone/;
        my $tz = `cat $log`;
        chomp ($tz);
        return $tz;
    }
    else {
        $log =~ s/.*_(\w+)\.log/$1/;
        return $log;
    }
}

my $log;
foreach $log (@logs) {

    my $host = $log;
    $host =~ s/$logdir\///;
    $host =~ s/\/.*//;
    print "HOST=$host\n";

    my $tz = &munge_tz($log);
    my $puttimes = $log;
    $puttimes =~ s/\.log$/.puttimes/;
    if (! (-f $puttimes) || ((stat $log)[9] >= (stat $puttimes)[9])) {
        # Create the puttimes file
        print "Creating $puttimes.\n";
        open (LOG, $log) || die;
        open (OUT, ">$puttimes") || die;
        print OUT "# date size ttl_sec lat_ms\n";
        while (<LOG>) {
            if (m/Put successful: size=(\d+) key=0x[0-9a-f]+ ttl_sec=(\d+) lat=(\d+) ms/) {
                my ($sz, $ttl, $lat) = ($1, $2, $3);
                my $date = &munge_date ($tz,$_);
                print OUT "$date $sz $ttl $lat\n";
            }
        }
        close (LOG);
        close (OUT);
    } 

    my $gettimes = $log;
    $gettimes =~ s/\.log$/.gettimes/;
    if (! (-f $gettimes) || ((stat $log)[9] >= (stat $gettimes)[9])) {
        # Create the gettimes file
        print "Creating $gettimes.\n";
        open (LOG, $log) || die;
        open (OUT, ">$gettimes") || die;
        print OUT "# date size lat_ms\n";
        while (<LOG>) {
            if (m/Get successful: key=0x[0-9a-f]+ lat=(\d+) ms/) {
                my $lat = $1;
                my $date = &munge_date ($tz,$_);
                print OUT "$date 0 $lat\n";
            }
            if (m/Get successful: key=0x[0-9a-f]+ size=(\d+) lat=(\d+) ms/) {
                my ($size, $lat) = ($1, $2);
                my $date = &munge_date ($tz,$_);
                print OUT "$date $size $lat\n";
            }
        }
        close (LOG);
        close (OUT);
    } 

    my $getfail = $log;
    $getfail =~ s/\.log$/.getfail/;
    if (! (-f $getfail) || ((stat $log)[9] >= (stat $getfail)[9])) {
        # Create the getfail file
        print "Creating $getfail.\n";
        open (LOG, $log) || die;
        open (OUT, ">$getfail") || die;
        print OUT "# date host key size ttl_remaining\n";
        while (<LOG>) {
            if (m/PutGetTest: giving up/) {
                my $date = &munge_date ($tz,$_);
                print OUT "$date $host 0 0 0\n";
            }
            if (m/Get failed: key=0x([0-9a-f]+) size=(\d+) ttl remaining=([-0-9]+) ms/) {
                my $date = &munge_date ($tz,$_);
                print OUT "$date $host $1 $2 $3\n";
            }
        }
        close (LOG);
        close (OUT);
    } 

    my $putfail = $log;
    $putfail =~ s/\.log$/.putfail/;
    if (! (-f $putfail) || ((stat $log)[9] >= (stat $putfail)[9])) {
        # Create the putfail file
        print "Creating $putfail.\n";
        open (LOG, $log) || die;
        open (OUT, ">$putfail") || die;
        print OUT "# date size ttl_sec lat_ms reason\n";
        while (<LOG>) {
            if (m/Put failed: size=(\d+) key=[0-9a-f ]+ *ttl_sec=(\d+) lat=(\d+) ms, reason=(\d+)/) {
                my ($sz, $ttl, $lat, $reason) = ($1, $2, $3, $4);
                my $date = &munge_date ($tz,$_);
                print OUT "$date $sz $ttl $lat $reason\n";
            }
        }
        close (LOG);
        close (OUT);
    } 

    my $lookup = $log;
    $lookup =~ s/\.log$/.lookup/;
    if (! (-f $lookup) || ((stat $log)[9] >= (stat $lookup)[9])) {
        # Create the lookup file
        print "Creating $lookup.\n";
        open (LOG, $log) || die;
        open (OUT, ">$lookup") || die;
        print OUT "# date lat_ms\n";
        while (<LOG>) {
            if (m/LookupTest: found 0x[0-9a-f]+ on 0x[0-9a-f]+, \d+\.\d+\.\d+\.\d+:\d+ in (\d+) ms/) {
                my $lat = $1;
                my $date = &munge_date ($tz,$_);
                print OUT "$date $lat\n";
            }
        }
        close (LOG);
        close (OUT);
    } 
}

