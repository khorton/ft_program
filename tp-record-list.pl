#!/usr/bin/perl
#
# Script to pull list of RV-8 flight test points from test_program table and
# write the list to tp_flown table.  The intent is that the script would be run
# following a flight, to make a record of the test points that were flown.
#

use strict;
use DBI;

my $test_card_home = "/Users/kwh/ftdata/ft_program";
my $flt_no = "";                # Flight number to save test point list for.

# check to see if there is a command line switch.  If not, flag an error.
if ($#ARGV >= 0) {
  $flt_no = $ARGV[0];
} else {
  print "useage: tp-record-list.pl n\n is the flight number to save the test point list for.\n";
  exit;
}

# Connect to the database.
my $dbh = DBI->connect("DBI:mysql:database=ft_program;host=localhost",
                       "ft", "ft",
                       {'RaiseError' => 1});


# Copy info from test_program table to tp_flown table.
my $sth = $dbh->prepare("INSERT ft_program.tp_flown (flt,test_program_id,sequence) SELECT ft_program.test_program.flt,ft_program.test_program.id,ft_program.test_program.sequence FROM ft_program.test_program WHERE ft_program.test_program.flt = $flt_no"); 
$sth->execute();
$sth->finish();

# Disconnect from the database.
$dbh->disconnect();

exit;

