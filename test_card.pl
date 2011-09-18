#!/usr/bin/perl
#
# Script to pull aircraft flight test points from MySQL database, write a LaTeX
# file which is then used to create a pdf flight test card.
#
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
# Version History
# v1.0      2011-09-17 Initial public release
#
#
#=============================================================================#
#
# Printing - Use A4 paper.  Select A4 paper in the FT_Card_Start.tex file 
#            (geometry package options).  Make sure that Page Setup in Preview 
#            A4 paper and portrait orientation.  Tell Preview to do two pages 
#            per sheet.
#
# To Do:  1. Add percentage of CG travel rather than just show number of inches
#            forward of datum
#
#         2. Allow Remarks entries in database that simply is a number of lines
#            with a return after each.  Translate this type of entry to a set
#            of \enumerate and \item entries.
#
#         3. Add code to enable all options (e.g. -q, -h)
#
#         4. Add code to create 2 up pdf file.  Use another latex file like:
# \documentclass[a4paper, landscape]{article}
# \usepackage{pdfpages}
# \begin{document}
# \includepdf[nup=2x1,pages=-]{Test_card_flt_15.pdf}
# \end{document}
#
# can specify a list of pages, in order, like:
# \includepdf[nup=2x1,pages={1,6,2,7,3,8,4,9,5}]{Test_card_flt_15.pdf}
#
# also, can send the latex commands to pdflatex on the command line, like:
# pdflatex "\documentclass[a4paper, landscape]{article} \usepackage{pdfpages} \begin{document} \includepdf[nup=2x1,pages=-]{Test_card_flt_15.pdf} \end{document}"
#
# in the above case, the output will be named article.pdf
#
#         5. Add new table that holds list of test points and sequence to be 
#            flown on each flight, to facilitate flying each test point 
#            multiple times.
#
#         6. Allow test programs for multiple aircraft in one mysql file.

# Done:   5. 20090227 - reworked to add new table that holds list of test 
#            points and sequence to be flown on each flight, to facilitate 
#            flying each test point multiple times.



use strict;
use DBI;
use File::Slurp;
use Getopt::Std;
use Date::Calc qw(:all);
# $opt_f = flight number
# $opt_h = history - i.e. get data for flight that has already occured 
# $opt_o = override weight and cg errors
# $opt_p = repeat procedure, even if it is the same as the previous test
# $opt_q = quiet - do not open the pdf file after creating it

our ($opt_f, $opt_h, $opt_o, $opt_p, $opt_q, $opt_d, $opt_w);
my $test_card_home = "/Users/kwh/sw_projects/hg/ft_program";
#my $test_card_home = "/home/user/hg/ft_program";

my $test_card_file_start = "/$test_card_home/FT_Card_Start.tex";
my $test_card_file_start_grd_run = "/$test_card_home/FT_Card_Start_Grd_Run.tex";
my $test_card_file_end = "$test_card_home/FT_Card_End.tex";
my $test_point_end = "/$test_card_home/tpend.tex";
my $tpstart_template = "";  # LaTeX statements to use at the start of every test point
my $tpstart = "";  # $tpstart_template with actual test replacing <<<test>>>
my $tpend = "";    # LaTeX statements to use at the end of every test point
my $wb_chart_data_file_name = "$test_card_home/wb/ft_card_wb.txt";
my $gnuplot_wb_file = "$test_card_home/wb/wb_chart_test_card.gp";
my $gnuplot_wb_file_template = "$test_card_home/wb/wb_chart_test_card_template.gp";
my $gnuplot_file = "";
my $gnuplot_directory = "$test_card_home/wb/";
my %gnuplot_labels = "";
my $gnuplot_start_label_x = "";
my $gnuplot_start_label_y = "";
my $gnuplot_end_label_x = "";
my $gnuplot_end_label_y = "";

my $query = "";                 # SQL query string
my $flt_no = "";                # Flight number to create the test card for.
my $manual_date = "";           # Manually entered date, to override date in database
my $OUTPUT_FILE = "";           # File name for LaTeX test card file to be created.
my @working_data = "";
my %data = "";                  # hash of info for each flight from the flights table
my %tpdata = "";                # speed, altitude, power, flaps, etc for each test point
my $template = "";              # path to relevant test point template file
my $last_test = "";             # name of last test, to see if the next one is the same type
my $template_home = "";         # location of template files for the current test point
my $empty_wt = "";
my $empty_moment = "";
my $pilot_arm = "91.78";
my $rear_seat_arm = "119.12";
my $fwd_baggage_arm = "58.51";
my $rear_baggage_arm = "138.00";
my $rear_baggage_shelf_arm = "152.91";
my $fuel_arm = "80.00";
my $ZFW = "";
my $ZFW_moment = "";
my $ZFW_CG = "";
my $TOW = "";
my $TOW_CG = "";
my $TOW_max = "1800";
my $fwd_cg_limit = "78.7";
my $aft_cg_limit = "86.82";
my $aerobatic_aft_cg_limit = "85.3";
my $max_min = "1782";           # min end of maximum weight band
my $hvy_min = "1750";           # min end of heavy weight band
my $med_max = "1650";           # max end of med weight band
my $med_min = "1500";           # min end of med weight band
my $lt_max = "1450";            # max end of light weight band
my $fwd_cg_max = "79.27";       # aft end of fwd cg band (7% of CG range behind fwd limit)
my $mid_cg_min = "80.73";       # fwd end of mid cg band (25% of CG range behind fwd limit)
my $mid_cg_max = "84.79";       # aft end of mid cg band (75% of CG range behind fwd limit)
my $aft_cg_min = "86.25";       # fwd end of aft cg band (93% of CG range behind fwd limit)
my $aero_cg_aft_min = "84.84"; # fwd end of aerobatic aft cg band (93% of aerobatic CG range aft of fwd limit)
my $aero_cg_aft_max = "85.3";   # aft end of aerobatic cg band
my $die_now = "";

my %options=();
my $sth = "";
my @purpose = "";
my @temp_purpose = "";
# my @Compact_Enum_input = "";
# my @temp_Compact_enum = "";
getopts("hopqwf:d:",\%options); 
$flt_no = $options{f};
$opt_o = $options{o};
$opt_w = $options{w};


if(defined $options{d}){
    $manual_date = $options{d};
    my ($year, $month, $day) = ($manual_date =~ /(\d\d\d\d)\D(\d\d)\D(\d\d)/);    
    if (check_date($year,$month,$day)) {
        $manual_date = $year . "-" . $month . "-" . $day;
        } elsif ($manual_date =~ /Today|today/){
            ($year,$month,$day) = Today();
            $manual_date = $year . "-" . $month . "-" . $day;
        } else{
            print "$manual_date is not a valid date.  The date must be in the format YYYY-MM-DD, or it must be 'today'.\n";
            exit;
    }
}

my $usage = "Flight or Ground Run number not defined (Ground Run numbers start with a G)\n
useage: test_card.pl -f n

n is the flight number to create the test card for.

Optional switches: -o override weight and cg errors
                   -d date - flight date.  Date must be in format YYYY-MM-DD, or it must be 'today'
                   -p procedure - repeat procedure even if next test point is the same type
                   -q quiet - do not open the pdf file after creating it\n
                   -w W&B - calculate weight and CG and exit";


if (!defined $options{f}) {
    print $usage;
    exit;
    }

# if (substr($flt_no, 0, 1) == "G") {
#     $opt_o = 1;
# }
# 
$tpstart_template = "\\begin{TestPoint}{<<<test>>>}";
$tpend = "\\end{TestPoint}\n\n\n";

# use different templates for start of test card, depending on whether we have
# a flight or a ground run (ground runs have negative flight numbers)
# if ($flt_no < 1) {
if (substr($flt_no, 0, 1) == "G") {
    $opt_o = 1;
  open (INPUT , '<' , "$test_card_file_start_grd_run")
    or die "Can't open $!";
    print "Ground test\n";
} else {
  open (INPUT , '<' , "$test_card_file_start")
    or die "Can't open $!";
}

@working_data = readline INPUT;

$OUTPUT_FILE = "$test_card_home/Test_card_flt_$flt_no";

open (OUTPUT , '>' , "$OUTPUT_FILE.tex")
  or die "Can't open test card file: $!";

# Connect to the database.
my $dbh = DBI->connect("DBI:mysql:database=ft_program;host=localhost",
                       "ft", "ft",
                       {'RaiseError' => 1});

# Pull info from flight table.
if (substr($flt_no, 0, 1) == "G") {
    $sth = $dbh->prepare("SELECT * FROM flights WHERE flt = \"$flt_no\"");
} else { 
    $sth = $dbh->prepare("SELECT * FROM flights WHERE flt = $flt_no"); 
}
$sth->execute();

while (my $ref = $sth->fetchrow_hashref()) {
  %data = (
                     date => $ref->{'date'},
                    pilot => $ref->{'pilot'},
                      fte => $ref->{'fte'},
                  purpose => $ref->{'purpose'},
                   flt_no => $flt_no,
                 pilot_wt => $ref->{'pilot_wt'},
             rear_seat_wt => $ref->{'rear_seat_wt'},
           fwd_baggage_wt => $ref->{'fwd_baggage_wt'},
          rear_baggage_wt => $ref->{'rear_baggage_wt'},
    rear_baggage_shelf_wt => $ref->{'rear_baggage_shelf_wt'},
                  fuel_wt => $ref->{'fuel_wt'},
              ballast1_wt => $ref->{'ballast1_wt'},
             ballast1_arm => $ref->{'ballast1_arm'},
              ballast2_wt => $ref->{'ballast2_wt'},
             ballast2_arm => $ref->{'ballast2_arm'}
    );
}
$sth->finish();

if ($manual_date){$data{date} = $manual_date}

$data{'purpose'} = Compact_Enum($data{'purpose'});

###############################################################################
# Pull info from limitations table.
if (substr($flt_no, 0, 1) == "G") {
    $sth = $dbh->prepare("SELECT * FROM limitations WHERE flt like \"$flt_no\"");
} else {
    $sth = $dbh->prepare("SELECT * FROM limitations WHERE flt = $flt_no"); 
}

$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {
  #$data{limitations} = $ref->{'latex'};
  # if ($ref->{'latex'} != "") {
  #   $data{limitations} = Compact_Enum($ref->{'latex'});
  # } else {
  #   $data{limitations} = "";
  # }
  if ($ref->{'latex'} == "") {
    $data{limitations} = "None"
  } else {
    $data{limitations} = Compact_Enum($ref->{'latex'});
  }
}
$sth->finish();



###############################################################################
#
# Create and write the weight and balance part of the test card
#
# Only do this for a flight, not a ground test
#
# Pull all weighing data from wb database

if ($flt_no >= 1) {
  my $sth = $dbh->prepare("SELECT * FROM wb ORDER BY date desc"); 
  $sth->execute();
  
  # select correct weighing data
  while (my $ref = $sth->fetchrow_hashref()) {
    if ($data{date} == "0000-00-00") {
      # flight date is blank, so use most recent weighing
      $empty_wt = $ref->{'wt'};
      $empty_moment = $ref->{'moment'};
      $data{date} = "\\hspace{1 in}";
      last;
    } else {
      # find the first weighing that is earlier than the flight date (if doing 
      # historical flight)
      if ($ref->{'date'} le $data{date}) {
        $empty_wt = $ref->{'wt'};
        $empty_moment = $ref->{'moment'};
        last;
      }
    }
  }
  
  $sth->finish();
  
  $data{date} = FormatDate($data{date});
  
  $data{empty_wt} = CommaFormatted(sprintf("%d",$empty_wt));
  $data{empty_moment} = CommaFormatted(sprintf("%.2f",$empty_moment));
  $data{empty_arm} = sprintf("%.2f",$empty_moment / $empty_wt);
  
  # calculate zero fuel weight and cg
  $ZFW =          $empty_wt 
                + $data{pilot_wt} 
                + $data{rear_seat_wt} 
                + $data{fwd_baggage_wt} 
                + $data{rear_baggage_wt} 
                + $data{rear_baggage_shelf_wt} 
                + $data{ballast1_wt} 
                + $data{ballast2_wt};
  
  $ZFW_moment = $empty_moment
                + $data{pilot_wt} * $pilot_arm
                + $data{rear_seat_wt} * $rear_seat_arm
                + $data{fwd_baggage_wt} * $fwd_baggage_arm
                + $data{rear_baggage_wt} * $rear_baggage_arm
                + $data{rear_baggage_shelf_wt} * $rear_baggage_shelf_arm
                + $data{ballast1_wt} * $data{ballast1_arm}
                + $data{ballast2_wt} * $data{ballast2_arm};
  
  $ZFW_CG = $ZFW_moment / $ZFW;
  
  # add fuel weight and moment to get take-off weight and CG
  $TOW = $ZFW + $data{fuel_wt};
  $TOW_CG = ($ZFW_moment + $data{fuel_wt} * $fuel_arm) / $TOW;
  
  if ($opt_w) {
      my $percent_CG_norm = ($TOW_CG - $fwd_cg_limit)/($aft_cg_limit - $fwd_cg_limit ) * 100;
      # print qq(The zero fuel weight and CG are: $ZFW lb at $ZFW_CG inches\n);
      printf "The zero fuel weight is %.0f lb.\n", $ZFW;
      printf "The take-off weight and CG are: %.0f lb at %.1f\",  %.1f\% aft of the forward limit.\n", $TOW, $TOW_CG, $percent_CG_norm ;
      exit;
  }
  
  open (WB_DATA , '>' , "$wb_chart_data_file_name")
    or die "Can't open weight and balance data file: $!";
  
  # print info header
  print WB_DATA "# Zero Fuel Weight CG and Take-off CG\n#inches_aft_of_datum lb\n";
  
  
  # print weight and balance data to a file to feed to gnuplot
  print WB_DATA "$ZFW_CG $ZFW\n$TOW_CG $TOW\n";
  
  
  $data{pilot_arm} = $pilot_arm;
  $data{pilot_moment} = CommaFormatted(sprintf("%.2f",$pilot_arm * $data{pilot_wt}));
  $data{rear_seat_arm} = $rear_seat_arm;
  $data{rear_seat_moment} = CommaFormatted(sprintf("%.2f",$rear_seat_arm * $data{rear_seat_wt}));
  $data{fwd_baggage_arm} = $fwd_baggage_arm;
  $data{fwd_baggage_moment} = CommaFormatted(sprintf("%.2f",$fwd_baggage_arm * $data{fwd_baggage_wt}));
  $data{rear_baggage_arm} = $rear_baggage_arm;
  $data{rear_baggage_moment} = CommaFormatted(sprintf("%.2f",$rear_baggage_arm * $data{rear_baggage_wt}));
  $data{rear_baggage_shelf_arm} = $rear_baggage_shelf_arm;
  $data{rear_baggage_shelf_moment} = CommaFormatted(sprintf("%.2f",$rear_baggage_shelf_arm * $data{rear_baggage_shelf_wt}));
  $data{ballast1_moment} = CommaFormatted(sprintf("%.2f",$data{ballast1_arm} * $data{ballast1_wt}));
  $data{ballast2_moment} = CommaFormatted(sprintf("%.2f",$data{ballast2_arm} * $data{ballast2_wt}));
  $data{zfw} = CommaFormatted(sprintf("%d", $ZFW));
  $data{zfw_cg} = sprintf("%.2f",$ZFW_CG);
  $data{zfw_moment} = CommaFormatted(sprintf("%.2f",$ZFW_CG * $ZFW));
  $data{fuel_arm} = $fuel_arm;
  $data{fuel_moment} = CommaFormatted(sprintf("%.2f",$fuel_arm * $data{fuel_wt}));
  $data{to_wt} = CommaFormatted(sprintf ("%d",$TOW));
  $data{to_cg} = sprintf ("%.2f",$TOW_CG);
  $data{to_moment} = CommaFormatted(sprintf("%.2f",$TOW * $TOW_CG));
  $data{wb_chart} = $gnuplot_directory . "wb_chart";
  
  # unless ($opt_o == "1") {
  unless ($opt_o) {
  #  print "Take off weight is $TOW.  MTOW is $TOW_max.\n";
    if ($TOW > $TOW_max) {
      $die_now ++;
      print qq(***The aircraft weight exceeds the MTOW.***\n);
    }
    
    if ($TOW_CG < $fwd_cg_limit) {
      $die_now ++;
      print qq(***The take-off CG is forward of the forward CG limit.***\n);
    }
  
    if ($TOW_CG > $aft_cg_limit) {
      $die_now ++;
      print qq(***The take-off CG is aft of the aft CG limit.***\n);
    }
  
    if ($ZFW_CG < $fwd_cg_limit) {
      $die_now ++;
      print qq(***The zero-fuel CG is forward of the forward CG limit.***\n);
    }
  
    if ($ZFW_CG > $aft_cg_limit) {
      $die_now ++;
      print qq(***The zero-fuel CG is aft of the aft CG limit.***\n);
    }
  }
  
  # write gnuplot file with fuel burn line and labels
  $gnuplot_file = read_file($gnuplot_wb_file_template);
  $gnuplot_start_label_x = $TOW_CG + 0.1;
  $gnuplot_start_label_y = $TOW;
  $gnuplot_end_label_x   = $ZFW_CG + 0.1;
  $gnuplot_end_label_y   = $ZFW;
  %gnuplot_labels = (
       START => "$gnuplot_start_label_x" . "," . "$gnuplot_start_label_y",
         END => "$gnuplot_end_label_x" . "," . "$gnuplot_end_label_y"
     );
  
  # Place label in gnuplot file.
  $gnuplot_file =~ s/<<<(\w+)>>>/$gnuplot_labels{$1}/g;
  
  # Place output file location in gnuplot file.
  $gnuplot_file =~ s/>>>GNUPLOT_DIR<<</$gnuplot_directory/g;
  
  
  open (GNUPLOT , '>' , "$gnuplot_wb_file")
    or die "Can't open test card file: $!";
  
  print GNUPLOT "$gnuplot_file\n";
  
  system "gnuplot $gnuplot_wb_file";
  system "epstopdf --outfile $test_card_home/wb/wb_chart.pdf $test_card_home/wb/wb_chart.eps";
}
###############################################################################


# Replace data in test card start file with data from the database.
foreach (@working_data) {
  $_ =~ s/<<<(\w+)>>>/$data{$1}/g;
}

# write start of test card, with placeholder data replaced with stuff from database
print OUTPUT "@working_data\n";

@working_data = ""; # flush the data

# Pull test points from the test_program table.
if (substr($flt_no, 0, 1) == "G") {
  # $query = "SELECT * FROM test_program WHERE flt = \"$flt_no\" ORDER BY sequence";
  $query = "SELECT test_program.id, flt_tp_list.flt, test, flt_tp_list.sequence, speed, altitude, power, flaps, remarks, wt, cg, latex, status, risk, tp FROM flt_tp_list INNER JOIN test_program ON test_program.id = flt_tp_list.tp_id WHERE flt_tp_list.flt = \"$flt_no\" ORDER BY sequence";
} else {
  # $query = "SELECT * FROM test_program WHERE flt = $flt_no ORDER BY sequence";
  $query = "SELECT test_program.id, flt_tp_list.flt, test, flt_tp_list.sequence, speed, altitude, power, flaps, remarks, wt, cg, latex, status, risk, tp FROM flt_tp_list INNER JOIN test_program ON test_program.id = flt_tp_list.tp_id WHERE flt_tp_list.flt = $flt_no ORDER BY sequence";
}

my $sth = $dbh->prepare("$query"); 
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {

    %tpdata = (
        test => uc ($ref->{'test'}),
       speed => $ref->{'speed'},
    altitude => CommaFormatted($ref->{'altitude'}),
       power => $ref->{'power'},
       flaps => $ref->{'flaps'},
          wt => $ref->{'wt'},
          cg => $ref->{'cg'},
          tp => $ref->{'tp'},
     remarks => $ref->{'remarks'},
        risk => $ref->{'risk'},
    );
  

    
# check test point weight and cg requirements against aircraft loading
unless ($opt_o) {
  $die_now += Verfiy_Wt_CG ( $tpdata{wt}, $tpdata{cg}, $tpdata{tp}, $tpdata{test}, $TOW, $TOW_CG );
}


# put test name in template
$tpstart = $tpstart_template;
$tpstart =~ s/<<<(\w+)>>>/$tpdata{$1}/g;

# check to see if speed field contains V + following letters that should be formatted
# as a subscript    
$tpdata{speed} =~ s/V(\w+)/\$\\mathrm{V_{$1}}\$/g;

# if speed is only digits, save digits for later use, and add units
$tpdata{speed} =~ s/^(\d+)$/$1 kt/g;
$tpdata{speed_digits} = $1;

# if altitude is only digits, add units
$tpdata{altitude} =~ s/^(\d+,*\d*)$/$1 ft/g;

# convert flaps to upper case
$tpdata{flaps} = uc($tpdata{flaps});

# convert power to upper case
$tpdata{power} = uc($tpdata{power});

# check for latex \textdegree in power
$tpdata{power} =~ s/\\TEXTDEGREE/\\textdegree/g;

# fix "%" in power, as latex sees "%" as a comment
# need two backslashes before the "%", as latex needs to get "\%", or it will
# be a comment, and perl eats one backslash.
$tpdata{power} =~ s/^(\d+)%/$1\\%/g;

  if ($ref->{'latex'}) {
    
    # Check to see if latex field is just a pointer to a template
    if ($ref->{'latex'} =~  /QQQ(\w+)WWW/) {
      $template_home = $test_card_home . "/" . $1 . "/";
      # see if this test is the same as the last one
      if ($last_test eq $1 && ($opt_p)) {
#      if ($last_test eq $1) {
        # same type of test as last time, so don't need to get Procedure again
        # get Conditions part of test card, if not a ground test
        if ($flt_no >= 1) {
          $template = $template_home . "conditions.tex";
          $ref->{'latex'} = read_file($template);
        print "In the loop.\n";
#        exit;
        }
        
        # get data recording part of test card
        $template = $template_home . "data.tex";
        $ref->{'latex'} = $ref->{'latex'} . read_file($template);
      } else {
        # different type of test from last time, so need to get Procedure and Risk
        # get Conditions part of test card, if not a ground test
        if ($flt_no >= 1) {
          $template = $template_home . "conditions.tex";
          $ref->{'latex'} = read_file($template);
        }

        # get Procedure part of test card
        $template = $template_home . "procedure.tex";
        $ref->{'latex'} = $ref->{'latex'} . read_file($template);
        
        $template = $template_home . "risk.tex";
        # check to see if risk.tex exists
        if (-e $template) {
          $ref->{'latex'} = $ref->{'latex'} . read_file($template);
        }
        
        # get data recording part of test card
        $template = $template_home . "data.tex";
        $ref->{'latex'} = $ref->{'latex'} . read_file($template);
      }

      # store type of test
      $last_test = $1;
    }
  } else {
    # no latex code for this test point
    $last_test = "";
#   get Conditions part of test card, if not a ground test
        if ($flt_no >= 1) {
          $template = $test_card_home . "/conditions.tex";
          $ref->{'latex'} = read_file($template);
        }
    
    # add remarks from database to put in Procedure part
    $ref->{'latex'} = $ref->{'latex'} . "\n" . "\\subsubsection*{Procedure}\n"; 
    # put any subscripts to V in correct format
    $ref->{'remarks'} =~ s/V(\w{1,4}\s)/\$\\mathrm{V_{$1}}\$/g;
    
    # fix any "%" so they are not seen as latex comments
    $ref->{'remarks'} =~ s/^(\d+)%/$1\\%/g;

    #convert remarks to LaTeX compactenum
    $ref->{'remarks'} = Compact_Enum($ref->{'remarks'});

    $ref->{'latex'} = $ref->{'latex'} . "\n" . $ref->{'remarks'} . "\n";
    
    # get data recording part of test card
    $ref->{'latex'} = $ref->{'latex'} . '\\include{Observations}' . "\n";

    
    
  }
#    insert test point data in place of the data in the template
     
     $ref->{'latex'} =~ s/<<<(\w+)>>>/$tpdata{$1}/g;
     push (@working_data, "$tpstart");
     push (@working_data, "$ref->{'latex'}");
     if ($ref->{'risk'}) {
       push (@working_data, "\\subsubsection*{Risk Mitigation} $ref->{'risk'}");
     }
#     push (@working_data, "RISK");
     push (@working_data, "$tpend");

}
$sth->finish();


# write LaTeX stuff for test points from database
print OUTPUT "@working_data\n";

# append document end from template file
open (INPUT , '<' , "$test_card_file_end")
  or die "Can't open $!";
  
@working_data = readline INPUT;

# write end of test card
print OUTPUT "@working_data\n";

# Disconnect from the database.
$dbh->disconnect();

# check to see if should die now due to wt or cg issues, or run the latex
if ($die_now > 0) {
  my $truncated_CG = sprintf("%.2f",$TOW_CG);
  die qq(\nAircraft weight is $TOW lb with a CG of $truncated_CG.
***There are $die_now weight or CG problems.***
run "test_card.pl -f $flt_no -o" to override the weight and CG errors.\n);
}


# 1 page per sheet option
# system "pdflatex -output-directory $test_card_home $OUTPUT_FILE";
# exec "open $OUTPUT_FILE.pdf";


# 2 pages per sheet option
system "latex -output-directory $test_card_home $OUTPUT_FILE";
system "dvips -t a4 -o $OUTPUT_FILE.ps $OUTPUT_FILE.dvi";
system "psnup -pa4 -2 -q $OUTPUT_FILE.ps $OUTPUT_FILE-2.ps";
system "ps2pdf13 -sPAPERSIZE=a4 $OUTPUT_FILE.ps $OUTPUT_FILE.pdf";

unless ($opt_q) {
    # exec "xpdf -z page $OUTPUT_FILE.pdf";
    system "open $OUTPUT_FILE.pdf";
    # sleep(5);
    # run Applescript to change paper to A4 and scaling to 100%
    # exec "open /Users/kwh/ft_program/Preview_to_A4.app";
}

# following line creates postscript output
#system "latex $OUTPUT_FILE";
#system "dvips -o $OUTPUT_FILE.ps $OUTPUT_FILE.dvi";

exit;
###############################################################################

sub CommaFormatted
# from http://www.web-source.net/web_development/currency_formatting.htm
{
        my $delimiter = ','; # replace comma if desired
        my($n,$d) = split /\./,shift,2;
        my @a = ();
        while($n =~ /\d\d\d\d/)
        {
                $n =~ s/(\d\d\d)$//;
                unshift @a,$1;
        }
        unshift @a,$n;
        $n = join $delimiter,@a;
        $n = "$n\.$d" if $d =~ /\d/;
        return $n;
}
# end of subroutine CommaFormatted
###############################################################################

sub FormatDate
# convert MySQL formatted date to human readable format.
# if date is blank, add a LaTeX box to hand write the date
# in later
{
  $_[0] =~ /(\d+)-(\d+)-(\d+)/;
  my $year = $1;
  my $month = $2;
  my $day = $3;
  
  if ($month == "1") {
    $month = "Jan";
  } else {
    if ($month == "2") {
      $month = "Feb";
    } else {
      if ($month == "3") {
        $month = "Mar";
      } else {
        if ($month == "4") {
          $month = "Apr";
        } else {
          if ($month == "5") {
            $month = "May";
          } else {
            if ($month == "6") {
              $month = "Jun";
            } else {
             if ($month == "7") {
               $month = "Jul";
              } else {
                if ($month == "8") {
                  $month = "Aug";
                } else {
                  if ($month == "9") {
                    $month = "Sep";
                  } else {
                    if ($month == "10") {
                      $month = "Oct";
                    } else {
                      if ($month == "11") {
                        $month = "Nov";
                      } else {
                        if ($month == "12") {
                          $month = "Dec";
                        } else {
                          return "\\begin{boxedminipage}{0.75 in}\\textcolor{white}{gl}\\end{boxedminipage}";
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }




  my $formatteddate = "$day $month $year";
  return $formatteddate;
}

###############################################################################
sub Verfiy_Wt_CG
# check to see if test point weight and CG callouts are compatible with the 
# aircraft weight and CG
#
# useage Verify_Wt_CG (test_pt_wt test_pt_CG test_pt_number aircraft_wt aircraft_CG)

{
  my $error = "0";
  if ($_[0] eq "hvy" & $TOW < $hvy_min) {
    print "tp $_[2] $_[3] calls for heavy weight but aircraft weight is less than $hvy_min lb.\n";
    $error ++;
  }
  
  if ($_[0] eq "max" & $TOW < $max_min) {
    print "tp $_[2] $_[3] calls for max weight but aircraft weight is less than $max_min lb.\n";
    $error ++;
  }
  
  if ($_[0] eq "med" & $TOW > $med_max) {
    print "tp $_[2] $_[3] calls for medium weight but aircraft weight is greater than $med_max lb.\n";
    $error ++;
  }

  if ($_[0] eq "med" & $TOW < $med_min) {
    print "tp $_[2] $_[3] calls for medium weight but aircraft weight is less than $med_min lb.\n";
    $error ++;
  }

  if ($_[0] eq "lgt" & $TOW > $lt_max) {
    print "tp $_[2] $_[3] calls for light weight but aircraft weight is greater than $lt_max lb.\n";
    $error ++;
  }

  if ($_[1] eq "fwd" & $TOW_CG > $fwd_cg_max) {
    print "tp $_[2] $_[3] calls for forward CG but aircraft CG is too far aft.\n";
    $error ++;
  }

  if ($_[1] eq "mid" & $TOW_CG < $mid_cg_min) {
    print "tp $_[2] $_[3] calls for mid CG but aircraft CG is too far forward.\n";
    $error ++;
  }

  if ($_[1] eq "mid" & $TOW_CG > $mid_cg_max) {
    print "tp $_[2] $_[3] calls for mid CG but aircraft CG is too far aft.\n";
    $error ++;
  }

  if ($_[1] eq "aft" & $TOW_CG < $aft_cg_min) {
    print "tp $_[2] $_[3] calls for aft CG but aircraft CG is too far forward.\n";
    $error ++;
  }

  if ($_[1] eq "aero_aft" & $TOW_CG < $aero_cg_aft_min) {
    print "tp $_[2] $_[3] calls for aerobatic aft CG but aircraft CG is too far forward.\n";
    $error ++;
  }

  if ($_[1] eq "aero_aft" & $TOW_CG > $aero_cg_aft_max) {
    print "tp $_[2] $_[3] calls for aerobatic aft CG but aircraft CG is too far aft.\n";
    $error ++;
  }

  return "$error";
}

###############################################################################
sub Compact_Enum
# take a block of text, and create a LaTeX \compactenum structure with each row 
# being a new \item.
{
    my $Compact_Enum_input = $_[0];
    my @temp_Compact_enum = "";
    my @temp_output = "";
    my $Output = "";

    # split input into lines, and change to compactenum for latex
    @temp_Compact_enum = split(/\n/, $Compact_Enum_input);
    $temp_output[0]="\\begin{compactenum}";
    push(@temp_output, "\\item " . $_) foreach @temp_Compact_enum;
    push(@temp_output, "\\end{compactenum}");
    $Output = join(" ", @temp_output);
    
    return $Output;
}
