#!/usr/bin/env perl

use strict;
use DBI;
use Cwd 'getcwd';

my $test_card_home = getcwd();
my $config_file = "$test_card_home/config.txt";
my $Config_key;
my %Config;
my $sth = "";
my %data = "";                  # hash of info for each flight from the flights table

# read config file
parse_config_file ($config_file, \%Config);
my $aircraft = $Config{'default_aircraft'};
my $aircraft = 'C-FTIO';
my $database = $Config{'database'};
my $database_user = $Config{'database_user'};
my $database_password = $Config{'database_password'};

# Connect to the database.
my $dbh = DBI->connect("DBI:mysql:database=$database;host=localhost",
                       "$database_user", "$database_password",
                       {'RaiseError' => 1});

my $w = 78600;
(my $f, $a) = CG_limits($dbh, $aircraft, $w);
print "fwd lim = $f, aft lim = $a\n";
exit;


# # check that the specified aircraft exists
# $sth = $dbh->prepare("SELECT * FROM aircraft WHERE registration = \'$aircraft\'"); 
# $sth->execute();
# if ($sth->rows < 1) {
#     print "Fatal Error - Aircraft $aircraft was not found in the database.\n";
#     exit;
# } elsif ($sth->rows > 1) {
#     print "Fatal Error - Aircraft $aircraft appears more than once in the database.\n";
#     exit;
# }
# 
# while (my $ref = $sth->fetchrow_hashref()) {
#   %data = (
#                      type => $ref->{'type'},
#                       MSN => $ref->{'serial_number'},
#                     owner => $ref->{'owner'},
#                     min_wt => $ref->{'min_wt'},
#                    fwd_wts => $ref->{'fwd_wts'},
#                    fwd_cgs => $ref->{'fwd_cgs'},
#                    aft_wts => $ref->{'aft_wts'},
#                    aft_cgs => $ref->{'aft_cgs'}
#     );
# }
# $sth->finish();
# 
# my @fwd_wts = split(',',$data{fwd_wts});
# my @fwd_cgs = split(',',$data{fwd_cgs});

# my ($wt, $cg) = (83000, 21);

# my $n = 0;
# my ($wt1, $cg1, $wt2, $cg2, $lim_cg) = (0, 0, 0, 0, 0);
# for $wt2 (@fwd_wts){
#     # print "$wt2, $fwd_cgs[$n]\n";
#     $cg2 = $fwd_cgs[$n];
#     if ($wt2 > $wt){
#         print "$wt2, $cg2\n";
#         print "$wt1, $cg1\n";
#         $lim_cg = $cg1 + ($cg2 - $cg1) * ($wt - $wt1) / ($wt2 - $wt1);
#         print "limit CG at $wt = $lim_cg\n";
#         if ($cg < $lim_cg){print "CG too far fwd\n"}
#         exit;
#     } else {
#         ($wt1, $cg1) = ($wt2, $cg2);
#     }
#     $n = $n + 1;
#     }
# my $fwd_line_len = @fwd_line;
# print "$fwd_line_len\n";

# read configuration file, from:
# http://www.motreja.com/ankur/examplesinperl/parsing_config_files.htm
sub parse_config_file {
    my ($config_line, $Name, $Value, $Config);

    (my $File, $Config) = @_;

    if (!open (CONFIG, "$File")) {
        print "ERROR: Config file not found : $File";
        exit(0);
    }

    while (<CONFIG>) {
        $config_line=$_;
        chop ($config_line);          # Get rid of the trailling \n
        $config_line =~ s/^\s*//;     # Remove spaces at the start of the line
        $config_line =~ s/\s*$//;     # Remove spaces at the end of the line
        if ( ($config_line !~ /^#/) && ($config_line ne "") ) {    # Ignore lines starting with # and blank lines
            ($Name, $Value) = split (/=/, $config_line);          # Split each line into name value pairs
            $Name =~ s/\s*$//;     # Remove spaces at the end of the Name
            $Value =~ s/^\s*//;     # Remove spaces at the start of the Value
            $$Config{$Name} = $Value;                             # Create a hash of the name value pairs
        }
    }

    close(CONFIG);

}

sub CG_limits {
    # for a given database handle, aircaft and weight, return forward and aft CG limits
    # also check whether specified weight is inside approved limits
    
    # usage sub($database_handle, $registration, $weight)    
    # returns ($fwd_limit, $aft_limit)
    
    my $database_handle = $_[0];
    my $registration = $_[1];
    my $weight = $_[2];

    $sth = $database_handle->prepare("SELECT * FROM aircraft WHERE registration = \'$registration\'"); 
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) {
    %data = (
              min_wt => $ref->{'min_wt'},
              max_wt => $ref->{'max_wt'},
             fwd_wts => $ref->{'fwd_wts'},
             fwd_cgs => $ref->{'fwd_cgs'},
             aft_wts => $ref->{'aft_wts'},
             aft_cgs => $ref->{'aft_cgs'}
                                         );
    }
    $sth->finish();

    if ($weight < $data{min_wt}) {
        print "Fatal error - specified weight is less than approved minimum flight weight\n";
        exit;
    }

    if ($weight > $data{max_wt}) {
        print "Fatal error - specified weight is greater than approved maximum take-off weight\n";
        exit;
    }

    my @fwd_wts = split(',',$data{fwd_wts});
    my @fwd_cgs = split(',',$data{fwd_cgs});
    my @aft_wts = split(',',$data{aft_wts});
    my @aft_cgs = split(',',$data{aft_cgs});

    my $ fwd_cg_lim = pull_CG_lim($weight, \@fwd_wts, \@fwd_cgs);
    my $ aft_cg_lim = pull_CG_lim($weight, \@aft_wts, \@aft_cgs);

    return ($fwd_cg_lim, $aft_cg_lim);
}

sub pull_CG_lim {
    # for a given weight and CG line points, return the limit CG
    # usage: pull_CG_lim($weight, @wts, @cgs)
    my ($weight, $wts, $cgs) = @_;
    my ($wt1, $cg1, $wt2, $cg2, $cg_lim, $n) = (0, 0, 0, 0, 0, 0);
    for $wt2 (@{$wts}) {
        $cg2 = $$cgs[$n];
        if ($wt2 == $weight) {
            $cg_lim = $cg2;
            last;
        } elsif ($wt2 >= $weight) {
            $cg_lim = $cg1 + ($cg2 - $cg1) * ($weight - $wt1) / ($wt2 - $wt1);
            last;
            } else {
                ($wt1, $cg1) = ($wt2, $cg2);
            }
        $n = $n + 1;
        }
    return $cg_lim;
    }