#!/usr/bin/perl -w
# 
# $Id: fetch-pl-logs.pl,v 1.5 2004/05/22 21:08:02 srhea Exp $
#
use strict;
use Fcntl ':flock';

my $desired_build = 20;
my @hostnames;
my $logdir = "/home/srhea/openhash-logs";

# Get the list of nodes.

print STDERR "Getting node list.\n";
my $url = 'http://appmanager.berkeley.intel-research.net/plcontrol/apps.php?appid=1001';
my $nodelist = "/tmp/nodelist-$$";
system ("curl '$url' 2>/dev/null > $nodelist") == 0 || die "Appmanager down?\n";

# Parse the list of hosts to see which are working.

open (NODELIST, $nodelist) || die;
unlink $nodelist;
while (<NODELIST>) {
    if (m!<TR><TD><FONT SIZE=2>([^<]+)</FONT></TD><TD BGCOLOR="[^"]+">([^<]+)</TD><TD BGCOLOR="[^"]+">([^<]+)</TD><TD BGCOLOR="[^"]+"><FONT SIZE=2>([^<]+)</FONT></TD><TD BGCOLOR="[^"]+">([^<]+)</TD><TD BGCOLOR="[^"]+"><FONT SIZE=2>([^<]+)</FONT></TD>!) {
        my ($hostname, $status, $requested, $contact, $build, $install) =
            ($1, $2, $3, $4, $5, $6);
        if ($build >= $desired_build && (! ($contact =~ m/day/))) {
            #print "$1 $2 $3 $4 $5 $6\n";
            push @hostnames, $hostname;
        }
    }
}
close (NODELIST);

# shuffle hostnames
for (my $i = 0; $i <= $#hostnames * 6; ++$i) {
    my $one = int (rand ($#hostnames + 1));
    my $two = int (rand ($#hostnames + 1));
    my $tmp = $hostnames[$one];
    $hostnames[$one] = $hostnames[$two];
    $hostnames[$two] = $tmp;
}

# ssh to each node and get any new logs

my $host;
foreach $host (@hostnames) {
    
    print STDERR "Checking node $host.\n";
    my $hostdir = "$logdir/$host";
    if (! (-d "$hostdir")) {
        system ("mkdir $hostdir") == 0 || die;
    }

    # Only run one instance of this program at a time.

    my $lockfile = "$hostdir/lock";
    system ("if ! test -f $lockfile; then touch $lockfile; fi") == 0 || die;
    open (LOCK,$lockfile);
    if (! flock (LOCK, LOCK_EX|LOCK_NB)) {
        print "Another copy of fetch-pl-logs.pl already working on $host.\n";
        close (LOCK);
        next;
    }

    my $lastread = undef;
    while (<LOCK>) {
        if (m/^(\d+)$/) {
            $lastread = $1;
            last;
        }
    }

    my $now = time;
    if ((defined $lastread) && ($now - $lastread < 3600)) {
        print "Already collected $host within the hour.\n";
        close (LOCK);
        next;
    }
    else {
        system ("echo $now > $lockfile") == 0 || die;
    }

    my $tmpfile = "$hostdir/lsout";
    if (system ("ssh ucb_bamboo\@$host 'ls -l logs' >$tmpfile") != 0) {
        print "ls failed on $host.\n";
        close (LOCK);
        next;
    }

    my @dates;
    my @files;
    my $j = 0;

    open (LSOUT, $tmpfile) || die;
    system ("rm -f $tmpfile") == 0 || die;
    while (<LSOUT>) {
        if (m/^[-rwx]+\s+\d+\s+ucb_bamboo\s+ucb_bamboo\s+\d+\s+(\w+\s+\d+\s+\d+:\d+)\s+(.+)$/) {
            my $date = $1;
            my $file = $2;
            #print "$date $file\n";
            $dates[$j] = $date;
            $files[$j] = $file;
            ++$j;
        }
    }
    close (LSOUT);

    for ($j = 0; $j <= $#dates; ++$j) {
        my $subdir = "$host";
        if ($files[$j] eq "log-5850") {
            system ("ssh ucb_bamboo\@$host 'date +%Z' > $hostdir/timezone") == 0 || die;
            print "Fetching $hostdir/latest.log\n";
            my $cmd = "rsync -t ucb_bamboo\@$host:logs/$files[$j]" .
                " $hostdir/latest.log";
            # print "  $cmd\n";
            if (system ($cmd) != 0) {
                print "Error with fetch\n";
                system ("rm -f $hostdir/latest.log");
            }
        }
        else {
            my $newdate = `ssh ucb_bamboo\@$host "date -d '$dates[$j]' '+%Y-%m-%d %k:%M %Z'"`;
            chomp ($newdate);
            # print "$dates[$j] $newdate\n";
            $dates[$j]=$newdate;
            $dates[$j] =~ s/ /_/g;
            $dates[$j] =~ s/:/\\:/g;
            my $logname = "$hostdir/$dates[$j].log";
            if (system ("test -f $logname") == 0) {
                print "Already have $logname\n";
            }
            else {
                print "Fetching $logname\n";
                my $cmd = "scp ucb_bamboo\@$host:logs/$files[$j] $logname";
                # print "  $cmd\n";
                if (system ($cmd) != 0) {
                    print "Error with fetch\n";
                    system ("rm -f $logname");
                }
            }
        }
    }

    # Release the lock.
    close (LOCK);
}


