ft_program - Automatic generation of flight test cards
by Kevin Horton, Ottawa, Canada
kevin01@kilohotel.com

These notes give a very top level description of a system to automatically
generate test cards for an aircraft flight test program.

License - All parts of this system are released under the Gnu Public License
          (GPL) version 3 or later.

Required software
  mysql
  perl
  gnuplot
  latex
  gs (ghostscript)

Installation
  Install and set up mysql.
  Install the example mysql database.
  Unpack all the other components at a location of your choice.
  Edit config.txt as required.

Paper size
  The system assumes the use of A4 paper, so that it may be printed out with 2 
  pages per sheet while keeping the same aspect ratio.


The system consists of the following components:

mysql database containing the list of test points
latex templates for the test card and for each major type of test.
test_card.pl - perl script that is run to generate a test card



The mysql database contains the following tables:
  flights - contains details of each flight, such as date, crew, test purpose, 
            aircraft loading, etc
  flt_tp_list - contains the test point ids and test point sequence for each 
                test flight
  limitations - contains list of aircraft limitations to be listed on the test
                card.  The idea is that the applicable limitations will vary as
                the aircraft flight envelope is opened up.
  test_program - the details of all test points in the test program
  wb - weight and balance info.  This table should be update each time the 
       aircraft empty weight or moment changes
  aircraft - contains data for each aircraft.

  The test_program table contains the following columns:
    flag - not required to generate a test card.  Used to mark test points to 
           be inserted in flt_tp_list, using mysql at the command line (see 
           list of example mysql commands below)
    sequence - not required to generate a test card.  Used to indicate the 
               test point sequence when test points are inserted in flt_tp_list
               (see list of example mysql commands below)
    test - very short test title
    speed - airspeed for test point
    altitude - altitude for test point
    power - power for test point
    flaps - flap angle for test point
    remarks
    wt - weight for test point.  One of lgt, med, hvy, max, opt or blank.  
         The weights for each of each bands is defined in test_card.pl 
         starting at line 105.
    cg - centre of gravity for test point.  One of fwd, mid, aft, aero_aft, 
         opt or bland.  The CG values for each of these bands is defined in 
         test_card.pl starting at line 110.
    tp - not required to generate a test card.  Test point number to identify 
         test point.
    phase - not required to generate a test card.  Used to assign test points 
            to specific test phases.  Intended to be used with the web 
            interface.
    id - unique test point id.  Used to specify test points in flt_tp_list.
    latex - pointer to latex template for this type of test.  If no latex 
            template exists, this field contains the raw latex code to generate
            the test card for that test.
    status - not required to generate a test card.  Indicates whether a test is
             not flown, flown but not complete or compete.
    risk - contains identified risks for each test point and risk mitigations.  
           May be blank.
    to_do - not required to generate a test card.

  The flt_tp_list table contains the following columns:
    flt - flight number
    tp_id - contains id from test_program table for each test point to be flown
    sequence - sequence number for each test.  A value between 0 and 127.  
               Allows test points to be reordered by changing the value in 
               this table.

  The wb table contains the following columns:
    aircraft - defines the aircraft that this row is for.  Value in this 
               column is the ID from the aircraft table.
    date - date of the weighing.  test_card.pl will choose the appropriate 
           weight and balance data based on the flight date and the dates in 
           this table.
    wt - empty weight
    moment - empty moment
    mtow - the maximum take-off weight for this aircraft on this date.
    remarks
    
  The aircraft table contains the following columns:
    id - unique aircraft id.  Used to identify the aircraft in the wb table.
    registration - aircraft registration (e.g. C-GNHK, or N123)
    type - aircraft model designation
    serial_number - aircraft serial number.
    owner - aircraft owner.
    min_wt - minimum approved flight weight
    max_wt - maximum approved take-off weight
    fwd_wts - list of weights that define all corner points on forward CG 
              limit.  Ordered from minimum to maximum weight.
    fwd_cgs - list of cgs that define all corner points on forward CG limit.  
              Each value corresponds to a value in the fwd_wts list.  Ordered 
              from minimum to maximum weight.

Interacting with the MySQL database
  An example MySQL database is provided in ft_program_multi_bu.sql.gz
  On OS X, Cocoa-MySQL and/or phpmyadmin are good free options to interact with
  the database. 

Web interface
  An abortive attempt to create a web interface to the database was started. It
  was eventually decided that the time required to learn php and finish the
  interface was greater than the total time that would be saved by its use.  The
  files are included on the off chance that some php guru wishes to finish it.

Example MySQL commands to interact with the database (note that some of these 
command lines were for an earlier set of tables and might not work with this version):

# log into mysql at command line (replace "<user_name>" in command below with 
# actual mysql user name):
mysql -u<user_name> -p ft_program_multi

The following commands are run in mysql, after logging in as shown above:

# Change phase to 4 in all rows where 'perf' is present in column TEST
UPDATE test_program SET phase = '4' WHERE MATCH (TEST) AGAINST ('+perf' IN BOOLEAN MODE)

# Change phase to 4 in all rows where 'perf' is present, but 'stall' is not present in column TEST
UPDATE test_program SET phase = '4' WHERE MATCH (TEST) AGAINST ('+perf' '-stall' IN BOOLEAN MODE)

# find all rows with speed of 100 and altitude of 5000
mysql> select * from test_program where speed = 100 AND altitude = 5000;

# extract specific columns where altitude = 5000 and speed = VH
mysql> select test, speed, altitude, wt, cg from test_program where altitude = 5000 AND speed = "vh";

# find rows where test contains "stall" and altitude = 5000
mysql> select test, speed, altitude, wt, cg from test_program WHERE MATCH (TEST) AGAINST ('+stall' IN BOOLEAN MODE) AND altitude = 5000;

# find data from one table that matches some data from another table
mysql> SELECT test_program.id, flt_tp_list.flt, test, flt_tp_list.sequence FROM flt_tp_list INNER JOIN test_program ON test_program.id = flt_tp_list.tp_id WHERE flt_tp_list.flt = 1 ORDER BY sequence; 

# Insert all test points with flag = 1 as test points for flight 23:
insert INTO flt_tp_list (flt, tp_id, sequence) SELECT 23, id, sequence FROM test_program WHERE flag = 1;
  
# Reset flags to 0 from 1:
update test_program set flag = '0' where flag = '1';
  
# Copy all test points in flight 24 to 25:
insert INTO flt_tp_list (flt, tp_id, sequence) SELECT 25, tp_id, sequence FROM flt_tp_list WHERE flt = 24;
  
# Move records where test contains stall, and flight = 26 to flight 27:
UPDATE flt_tp_list INNER JOIN test_program ON test_program.id = flt_tp_list.tp_id SET flt = '27'  WHERE MATCH (test_program.test) AGAINST ('+stall' IN BOOLEAN MODE) AND flt_tp_list.flt = '26';

# View details of tests on flight 26, using data from test_program table for 
# test points listed in flt_tp_list table:
select flt_tp_list.sequence, test, speed, altitude, power, flaps from test_program JOIN flt_tp_list ON (flt_tp_list.tp_id = test_program.id) WHERE flt_tp_list.flt = '53' order by flt_tp_list.sequence;
