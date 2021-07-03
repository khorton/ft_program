#!/usr/bin/env perl
#
# Script to insert flight test points into MySQL database
#
# The script takes the tp number of an existing test point, a range of speeds
# and a speed increment, and creates new test points to cover the range.
#
# Useage - insert_tp.pl -t test_point_number_to_copy -n new_test_point_number_for_first_point -i test_point_number_increment -s1 min_speed -s2 max_speed -si speed increment
#
# e.g.:
# insert_tp.pl -t 3.01 -s 60 -e 120 -n 3.0101 -i 0.0001 -v 20

#=============================================================================#
# copyright 2011 Kevin Horton
#
# This file is part of ft_program.
# 
#     ft_program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     ft_program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with ft_program.  If not, see <http://www.gnu.org/licenses/>.
#=============================================================================#


use strict;
use DBI;
use Getopt::Std;

# $opt_t = test point number to copy
# $opt_n = new test point number for first new point
# $opt_i = increment for new test point numbers
# $opt_s = start speed (speed for first test point)
# $opt_e = end speed (speed for last test point)
# $opt_v = speed increment

my %tpdata = "";                # speed, altitude, power, flaps, etc for each test point
my $tp = "";
my $speed = "";
our ($opt_t, $opt_n, $opt_i, $opt_s, $opt_e, $opt_v);



getopt("tnisev");  

# Connect to the database.
my $dbh = DBI->connect("DBI:mysql:database=ft_program;host=localhost",
                       "ft", "ft",
                       {'RaiseError' => 1});


# Pull test point to copy from the test_program table.
my $sth = $dbh->prepare("SELECT * FROM test_program WHERE tp = $opt_t "); 

$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {

    %tpdata = (
        test => $ref->{'test'},
    altitude => $ref->{'altitude'},
       power => $ref->{'power'},
       flaps => $ref->{'flaps'},
          wt => $ref->{'wt'},
          cg => $ref->{'cg'},
       latex => $ref->{'latex'},
     remarks => $ref->{'remarks'},
    );
}

$sth->finish();

$tp = $opt_n;

my $sth = $dbh->prepare(q{
  INSERT INTO test_program (test, speed, altitude, power, flaps, remarks, wt, cg, tp, flt, latex) VALUES (?,?,?,?,?,?,?,?,?,?,?)
  }) or die $dbh->errstr;
  
for ($speed = $opt_s; $speed <= $opt_e; $speed += $opt_v) {
  $sth->execute($tpdata{test}, $speed, $tpdata{altitude}, $tpdata{power}, $tpdata{flaps}, $tpdata{remarks}, $tpdata{wt}, $tpdata{cg}, $tp, "-", $tpdata{latex}) or die $dbh->errstr;
  $tp += $opt_i;
}

$dbh->disconnect();
exit;

