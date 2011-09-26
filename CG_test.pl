#! /usr/bin/perl

use strict;

my @fwd_wts = (48800, 78600, 85000, 96250, 99500);
my @fwd_cgs = (   23,    23,    20,    20, 21.6);
my ($wt, $cg) = (83000, 21);
# print "$wt/$cg\n";

my $n = 0;
my ($wt1, $cg1, $wt2, $cg2, $lim_cg) = (0, 0, 0, 0, 0);
for $wt2 (@fwd_wts){
    # print "$fwd_wt, $fwd_cgs[$n]\n";
    $cg2 = $fwd_cgs[$n];
    if ($wt2 > $wt){
        print "$wt2, $cg2\n";
        print "$wt1, $cg1\n";
        $lim_cg = $cg1 + ($cg2 - $cg1) * ($wt - $wt1) / ($wt2 - $wt1);
        print "limit CG at $wt = $lim_cg\n";
        if ($cg < $lim_cg){print "CG too far fwd\n"}
        exit;
    } else {
        ($wt1, $cg1) = ($wt2, $cg2);
    }
    $n = $n + 1;
    }
# my $fwd_line_len = @fwd_line;
# print "$fwd_line_len\n";

exit;