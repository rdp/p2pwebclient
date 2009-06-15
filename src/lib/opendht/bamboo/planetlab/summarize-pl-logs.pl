#!/usr/bin/perl -w
# 
# $Id: summarize-pl-logs.pl,v 1.1 2004/05/08 02:24:51 srhea Exp $
#
use strict;
my $logdir = "/home/srhea/openhash-logs";

print  "            Count  Median (ms)  Mean (ms)  Max (ms)  % Failed\n";
print  "            -----  -----------  ---------  --------  --------\n";

my $startstr = $ARGV[0];
my $endstr = $ARGV[1];

my $starttime = `date -d '$startstr' +\%s`;
my $endtime = `date -d '$endstr' +\%s`;
chomp ($starttime);
chomp ($endtime);

my $tmpfile = "/tmp/summarize-pl-logs-$$";

system ("find $logdir/ -name '*.lookup' | xargs cat | awk '{if (\$1 >= $starttime && \$1 <= $endtime) print;}' | stats.pl 2 > $tmpfile");

my $lkcnt = `grep 'data points' $tmpfile`;
chomp ($lkcnt);
$lkcnt =~ s/ data points//;

my $lkmean = `grep '^mean:' $tmpfile`;
chomp ($lkmean);
$lkmean =~ s/mean: //;

my $lkmed = `grep '^median:' $tmpfile`;
chomp ($lkmed);
$lkmed =~ s/median: //;

my $lkmax = `grep '^max:' $tmpfile`;
chomp ($lkmax);
$lkmax =~ s/max: //;

printf "Lookups:  %7d %8.0f %11.0f %11.0f      ???\n", 
    $lkcnt, $lkmed, $lkmean, $lkmax;

unlink $tmpfile;


system ("find $logdir/ -name '*.gettimes' | xargs cat | awk '{if (\$1 >= $starttime && \$1 <= $endtime) print;}' | stats.pl 3 > $tmpfile");

my $getcnt = `grep 'data points' $tmpfile`;
chomp ($getcnt);
$getcnt =~ s/ data points//;

my $getmean = `grep '^mean:' $tmpfile`;
chomp ($getmean);
$getmean =~ s/mean: //;

my $getmed = `grep '^median:' $tmpfile`;
chomp ($getmed);
$getmed =~ s/median: //;

my $getmax = `grep '^max:' $tmpfile`;
chomp ($getmax);
$getmax =~ s/max: //;

my $getfail = `find $logdir/ -name '*.getfail' | xargs cat | awk '{if (\$1 >= $starttime && \$1 <= $endtime) print;}' | wc -l`;
chomp ($getfail);

printf "Gets:     %7d %8.0f %11.0f %11.0f %8.1f\n", 
    $getcnt, $getmed, $getmean, $getmax, 100*$getfail/$getcnt;

unlink $tmpfile;


system ("find $logdir/ -name '*.puttimes' | xargs cat | awk '{if (\$1 >= $starttime && \$1 <= $endtime) print;}' | stats.pl 4 > $tmpfile");

my $putcnt = `grep 'data points' $tmpfile`;
chomp ($putcnt);
$putcnt =~ s/ data points//;

my $putmean = `grep '^mean:' $tmpfile`;
chomp ($putmean);
$putmean =~ s/mean: //;

my $putmed = `grep '^median:' $tmpfile`;
chomp ($putmed);
$putmed =~ s/median: //;

my $putmax = `grep '^max:' $tmpfile`;
chomp ($putmax);
$putmax =~ s/max: //;

my $putfail = `find $logdir/ -name '*.putfail' | xargs cat | awk '{if (\$1 >= $starttime && \$1 <= $endtime) print;}' | wc -l`;
chomp ($putfail);

printf "Puts:     %7d %8.0f %11.0f %11.0f %8.1f\n", 
    $putcnt, $putmed, $putmean, $putmax, 100*$putfail/$putcnt;

unlink $tmpfile;

