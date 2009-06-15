#!/usr/bin/perl -w
# 
# $Id: hash-host.pl,v 1.1 2004/05/14 01:01:58 srhea Exp $
#
use strict;
if ($#ARGV + 1 != 2) {
    print STDERR "usage: hash-host.pl <hostname> <probability>\n";
    exit 2;
}
my $host = $ARGV[0];
my $prob = $ARGV[1];
$prob = int($prob*100);
my $result = 0;
my @chars = split //, $host;
for (my $i = 0; $i <= $#chars; ++$i) {
    $result = $result * 7 + ord($chars[$i]);
}
if ($result % 101 < $prob) {
    exit 0;
}
else {
    exit 1;
}
