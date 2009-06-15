#!/usr/bin/perl -w
use strict;
  
my $content_file = shift;
open (FILE, "$content_file") or die "Could not open $content_file";

print<<EOF;
<html>
<head>
<title>OpenDHT: A Publicly Accessible DHT Service</title>
<style type="text/css">
  body { margin-top: 2em; margin-bottom: 2em;
         margin-left: 3em; margin-right: 3em; }
</style>
</head>

<body bgcolor="#ffffff">

<center>
<table border="0" cellspacing="0">
<tr>
<td><img align="left" width=445 height=148 src="opendht-logo.png"></td>
<td></td>
<td vAlign="center">
<img align="left" width=129 height=132 src="turnon.png"></td>
</tr>
</table>
</center>

<p>
<center>
<table width="100%">
<tr>
<td align="center"><a href="index.html">Introduction</a></td>
<td align="center"><a href="users-guide.html">User's Guide</a></td>
<td align="center"><a href="faq.html">FAQ</a></td>
<td align="center"><a href="pubs.html">Publications</a></td>
<td align="center"><a href="cgi-bin/mailman/listinfo/opendht-users">Mailing List</a></td>
<td align="center"><a href="people.html">People</a></td>
</tr>
</table>
</center>

<p>

EOF

my $match = "\\\$" . "Id:.* (\\d\\d\\d\\d\\/\\d\\d\\/\\d\\d "
    . "\\d\\d:\\d\\d:\\d\\d) .*\\\$";

my $last_mod;
while (<FILE>) {
    
    if (m/$match/) {
        $last_mod = $1;
    }
    print;
}
close (FILE);

if (defined $last_mod) {
    print "<p><hr><table cellpadding=\"2\" width=\"100%\"><tr><td valign=\"top\"><em>Last modified $last_mod GMT.</em></td><td align=\"right\"><a href=\"http://planet-lab.org/\"><img border=0 src=\"http://opendht.org/powered_by_pl.gif\"></img></a></td></tr></table>\n";
}

print<<EOF;

</body>
</html>
EOF

