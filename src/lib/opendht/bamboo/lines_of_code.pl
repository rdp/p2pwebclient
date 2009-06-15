#!/usr/bin/perl -w
#
# Author: Dennis Geels
# Modified from find2perl output

use strict;
require "find.pl";
use Getopt::Std;
use vars qw( $name $opt_a );

getopts('a') or die( "could not read options" );
my $print_all_stats = $opt_a;

# Called by &find() for each filename in tree:
#
# Preset variables:  "$dir, $_, $name = $dir/$_.
sub wanted {
    if( $_ !~ /^.*\.java$/ ) {
	return 0;
    } else {
	&process_file( $_, $name );
    }
}

# A single global hashtable to hold all statistics.
my %stats;

# Called by &wanted for each "*.java" file:
sub process_file {
    my ($filename, $fullname) = @_;

    #print "$filename\n";

    open( IN, "<$filename" ) or die "Can't open $filename\n";
    undef $/;
    my $code_string = <IN>;
    close( IN );

    # Keep all authors of this file in a hashtable.
    my %authors;
    my $author;
    while( $code_string =~ /\s*\/?\*+\s*\@author\s*(.*?)\s*\n/gs ) {
	if( ! defined $1 ) {
	    die( "Matched without matching?" );
	}
	$author = $1;
	
	if( $author =~ /Chris W.lls/ ) {
	    $author = "Chris Wells";
	} elsif( $author =~ /Weis/ ) {
	    $author = "Steve Weis";
	} elsif( $author =~ /Rob von Behren/ ) {
	    $author = "Rob von Behren";
	} elsif( $author =~ /Ben .*Zhao/ ) {
	    $author = "Ben Y. Zhao";
	} elsif( $author =~ /Matt Welsh/ ) {
	    $author = "Matt Welsh";
	} elsif( $author =~ /Weaterspoon/ ) {
	    $author = "Hakim Weatherspoon";
	} elsif( $author =~ /Westley Weimer/ ) {
	    $author = "Westley Weimer";
	} elsif( $author =~ /Larry .*Tung/ ) {
	    $author = "Larry H. Tung";
	}
	$authors{$author} = 1;
    }
    
    if( ! keys %authors ) {	# no authors found.
#	warn( "No author\n" );
	if( $fullname =~ /mdw/ ) {
	    $author = "Matt Welsh";
	} elsif( $fullname =~ /ofs/ ) {
	    $author = "OFS dir ";
	} else {
	    $author = "unclaimed";
	    print "$filename is unclaimed\n";
	}
	$authors{$author} = 1;
    }
    
    #print "author: $author\n";
    
#    study $code_string;
    my $chars = length( $code_string );
#    print "chars: $chars\n";
    my $lines = ($code_string =~ s|\n|\n|gs);
#    print "lines: $lines\n";

    # Count semicolons:
    my $semicolons = ($code_string =~ s|;|;|gs);
#    print( "semicolons: $semicolons\n" );

    # Count, remove blank lines:
    my $blanks = ($code_string =~ s|^\s*?\n||gm);

#    print "blanks: $blanks\n";

    my $chars_e = length( $code_string );
#    print "chars: $chars\n";
    my $lines_e = ($code_string =~ s|\n|\n|gs);    
#    print "lines: $lines\n";
    
    # Count, remove comments:
    my $comments = ($code_string =~ s|/\*(.*?)\*/||gs);
    # Don't count my section headers (anything with more than two '/'.
    $code_string =~ s|///.*?\n||gs;
    $comments += ($code_string =~ s|//.*?\n|\n|gs);
    
#    print "comments: $comments\n";

    # Remove any newly-blank lines and recount
    $code_string =~ s|^\s*?\n||gm;
    
    my $chars_f = length( $code_string );
#    print "chars: $chars\n";
    my $lines_f = ($code_string =~ s|\n|\n|gs);    
#    print "lines: $lines\n";

    # Remove lines with single brace, recount
    my $weak = ($code_string =~ s|^\s*?\}\s*?\n||gm);
    $weak += ($code_string =~ s|^\s*?\{\s*?\n||gm);

#    print "weak: $weak\n";
    my $chars_g = length( $code_string );
#    print "chars: $chars\n";
    my $lines_g = ($code_string =~ s|\n|\n|gs);    
#    print "lines: $lines\n";

    foreach $author (keys %authors) {
    
	push @{$stats{$author}{"files"}}, $fullname;
	$stats{$author}{"chars"} += $chars;
	$stats{$author}{"lines"} += $lines;
	$stats{$author}{"semicolons"} += $semicolons;
	$stats{$author}{"blanks"} += $blanks;
	$stats{$author}{"chars_e"} += $chars_e;
	$stats{$author}{"lines_e"} += $lines_e;
	$stats{$author}{"comments"} += $comments;
	$stats{$author}{"chars_f"} += $chars_f;
	$stats{$author}{"lines_f"} += $lines_f;
	$stats{$author}{"weak"} += $weak;
	$stats{$author}{"chars_g"} += $chars_g;
	$stats{$author}{"lines_g"} += $lines_g;
    }
}


# Walk the filesystem tree rooted here, using &wanted and &exec.
&find('.');

# Print out unclaimed files.
# my $list_ref = $stats{"unclaimed"}{"files"};
# print "unclaimed files:\n" . join( "\n", @$list_ref ) . "\n";
# print "\n\n\n";

# Now dump stats
if( $print_all_stats ) {
    print "Name\t\t Files\t Size\t Lines\t Semis\t Blanks\t Comms\t "
	. "Weak\t Size\t Lines\t Size\t Lines\n";
} else {
    print "Name\t\t Files\t Size\t Lines (Real)\t Semis\t Blanks\t Comms (Lines)\n";
}
my $author;
foreach $author 
    (sort { $stats{$a}{"lines"} <=> $stats{$b}{"lines"} }keys %stats) {
    my $list_ref = $stats{$author}{"files"};
    my $nick = substr $author, 0, 12;
    my $chars = int( $stats{$author}{"chars"} / 1024 );
    $stats{$author}{"chars"} = "${chars}KB";
    $chars = int( $stats{$author}{"chars_f"} / 1024 );
    $stats{$author}{"chars_f"} = "${chars}KB";    
    $chars = int( $stats{$author}{"chars_g"} / 1024 );
    $stats{$author}{"chars_g"} = "${chars}KB";    

    # next if( $stats{$author}{"lines"} < 1000 );
    
    if( $print_all_stats ) {
	print "$nick:\t " . scalar( @$list_ref ) . "\t " .
	$stats{$author}{"chars"} . "\t " .
	$stats{$author}{"lines"} . "\t " .
	$stats{$author}{"semicolons"} . "\t " .
	$stats{$author}{"blanks"} . "\t " .
	$stats{$author}{"comments"} . "\t " .
	$stats{$author}{"weak"} . "\t " .
	$stats{$author}{"chars_f"} . "\t " .
	$stats{$author}{"lines_f"} . "\t " .
	$stats{$author}{"chars_g"} . "\t " .
	$stats{$author}{"lines_g"} . "\n";
    } else {
	print "$nick:\t " . scalar( @$list_ref ) . "\t " .
	$stats{$author}{"chars"} . "\t " .
	$stats{$author}{"lines"} . " (" .
	substr( ($stats{$author}{"lines_f"}/$stats{$author}{"lines"}), 0, 5)
	    . ")\t " .
	$stats{$author}{"semicolons"} . "\t " .
	$stats{$author}{"blanks"} . "\t " .
	$stats{$author}{"comments"} . " (" .
	($stats{$author}{"lines_e"}-$stats{$author}{"lines_f"}) . ")\n";	    
    }
    
    if( $author eq "Dennis Geels" ) {
#	print "files:\n" . join( "\n", @$list_ref ) . "\n";
    }
}


exit;
