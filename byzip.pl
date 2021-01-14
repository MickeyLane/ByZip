#!C:/Strawberry/perl/bin/perl.exe
#!/usr/bin/perl
use warnings FATAL => 'all';
use strict;

#
# This software is provided as is, where is, etc with no guarantee that it is
# fit for any purpose whatsoever. Use at your own risk. Mileage may vary.
#
# You are free to do whatever you want with it. It would be nice if you gave credit
# to the author (Mickey Lane, chiliwhiz@gmail.com) if the situation warrants.
#
# This is a simulator. That means that while some of the input data may be real (or
# as real as the dept of health has decided to make it), all of the output is speculation.
# 

use File::Find;           
use File::chdir;
use File::Basename;
use Cwd qw(cwd);
use List::Util qw (shuffle);
use POSIX;
use File::Copy;
use DateTime;
use List::Util qw (max);
use Config::IniFiles;

use lib '.';
use byzip_c;
use byzip_v;
use byzip_plot;
use byzip_debug;
use byzip_setup;
use byzip_mt;
use byzip_make_random_choices;
use byzip_delete_cases;
use byzip_collect;

package main;

#
# Get current directory and determine platform
#
my $cwd = Cwd::cwd();
my $windows_flag = 0;
if ($cwd =~ /^[C-Z]:/) {
    $windows_flag = 1;
}

#
# All the personalization lives in local_lookup_settings.ini. Read that and init
# the lookup hash
#
my $h_ptr = read_ini_file();
my %lookup_hash = %$h_ptr;

my $root = $lookup_hash{'root'};
if (!(defined ($root))) {
    die "Root not defined";
}

my $now = DateTime->now;
$lookup_hash{'todays_date_string_for_directories'} = sprintf ("%04d-%02d-%02d", $now->year(), $now->month(), $now->day());
$lookup_hash{'todays_date_string_for_file_names'} = sprintf ("%04d %02d %02d", $now->year(), $now->month(), $now->day());

#
# Set program parameters
#
my $pp_report_sim_messages = 0;
my $pp_report_adding_case = 0;
my $pp_dont_do_sims = 0;
my $pp_report_header_changes = 0;

#
# COMMAND LINE PROCESSING
# =======================
#
# Set defaults
#
my $number_of_sims = 3;
my $zip_string;
my $duration_min = 9;
my $duration_max = 19;
my $untested_positive = 0;
my $severity = '40:40:20';
my $plot_output_flag = 0;
my $max_cured = 0;
my $max_cured_line_number = __LINE__;
my $report_data_collection_messages = 0;  # default 'no'
my $begin_sim_dt;
my $begin_display_dt;
#
# Set default for mortality rate. The mortality table seems to be broken as of 7 Dec
#
my $manually_set_mortality_rate;

#
# Get input arguments
#
my $untested_positive_switch = 'untested_positive=';
my $untested_positive_switch_string_len = length ($untested_positive_switch);

my $max_display_switch = 'cured_max_display=';
my $max_display_switch_string_len = length ($max_display_switch);

my $report_collection_switch = 'report_collection=';
my $report_collection_switch_string_len = length ($report_collection_switch);

my $first_sim_date_switch = 'first_sim_date=';
my $first_sim_date_switch_string_len = length ($first_sim_date_switch);

my $first_display_date_switch = 'first_display_date=';
my $first_display_date_switch_string_len = length ($first_display_date_switch);

foreach my $switch (@ARGV) {
    my $lc_switch = lc $switch;
    if (index ($lc_switch, 'zip=') != -1) {
        my $temp_zip_string = substr ($switch, 4);
        my $first_space = index ($temp_zip_string, ' ');
        if ($first_space != -1) {
            $zip_string = substr ($temp_zip_string, 0, $first_space);
        }
        else {
            $zip_string = $temp_zip_string;
        }
    }
    elsif (index ($lc_switch, 'mortality=') != -1) {
        $manually_set_mortality_rate = substr ($switch, 10);
    }
    elsif (index ($lc_switch, 'sims=') != -1) {
        $number_of_sims = substr ($switch, 5);
    }
    elsif (index ($lc_switch, 'duration_min=') != -1) {
        my $val = substr ($switch, 13);
        $duration_min = int ($val);
    }
    elsif (index ($lc_switch, 'duration_max=') != -1) {
        my $val = substr ($switch, 13);
        $duration_max = int ($val);
    }
    elsif (index ($lc_switch, $max_display_switch) != -1) {
        my $val = substr ($switch, $max_display_switch_string_len);
        $max_cured = int ($val);
    }
    elsif (index ($lc_switch, 'plot=') != -1) {
        my $val = substr ($switch, 5);
        if ($val =~ /[^01]/) {
            print ("Invalid plot switch. Should be 0 or 1\n");
            exit (1);
        }
        $plot_output_flag = int ($val);
    }
    elsif (index ($lc_switch, $untested_positive_switch) != -1) {
        my $val = substr ($switch, $untested_positive_switch_string_len);
        $untested_positive = int ($val);
    }
    elsif (index ($lc_switch, $report_collection_switch) != -1) {
        my $val = substr ($switch, $report_collection_switch_string_len);
        $report_data_collection_messages = int ($val);
    }
    elsif ($lc_switch eq 'help' || $lc_switch eq 'h') {
        print_help ($duration_min, $duration_max);
        exit (1);
    }
    elsif (index ($lc_switch, $first_sim_date_switch) != -1) {
        my $val = substr ($lc_switch, $first_sim_date_switch_string_len);
        if ($val =~ /(\d{4})-(\d{2})-(\d{2})/) {
            $begin_sim_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3)
        }
        else {
            print ("Invalid argument to $first_sim_date_switch\n");
            exit (2);
        }
    }
    elsif (index ($lc_switch, $first_display_date_switch) != -1) {
        my $val = substr ($lc_switch, $first_display_date_switch_string_len);
        if ($val =~ /(\d{4})-(\d{2})-(\d{2})/) {
            $begin_display_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3)
        }
        else {
            print ("Invalid argument to $first_display_date_switch\n");
            exit (2);
        }
    }
    else {
        print ("Don't know what to do with $switch\n");
        exit (1);
    }
}

my ($state, $lookup_hash_ptr) = choose_state ($zip_string, \%lookup_hash);
%lookup_hash = %$lookup_hash_ptr;

#
# SETUP
# =====
#
# Select state, pick directories, inventory directories, make missing directories
#
my ($status, $dir, $date_dirs_list_ptr, $hash_ptr) = byzip_setup::setup (
    $state, \%lookup_hash, $windows_flag, $begin_sim_dt);
if ($status == 0) {
    exit (1);
}
%lookup_hash = %$hash_ptr;
my @date_dirs = @$date_dirs_list_ptr;

#
# REPORT SIMULATION PARAMETERS
# ============================
#
print ("Simulation values:\n");
print ("  Zip = $zip_string\n");
print ("  State = $state\n");
if (defined ($manually_set_mortality_rate)) {
    print ("  Mortality = $manually_set_mortality_rate percent\n");
}
else {
    print ("  Mortality = using OWID derived table of daily percentage rates\n");
}
print ("  Duration_min = $duration_min days\n");
print ("  Duration_max = $duration_max days\n");
print ("  Untested = add $untested_positive untested positive cases for every one detected\n");
# print ("  Severity = $severity disease severity groups: no symptoms, moderate and severe\n");
# print ("      (Values are percents, total must be 100)\n");
print ("  Plot output = $plot_output_flag (0 = no, 1 = yes)\n");
print ("  Clip cured plot line at $max_cured. (Use $max_display_switch)\n");
print ("  Current working directory is $dir\n");

my $case_serial_number = 1;

#
# Make a list of zips to test. Could be only one
#
my @zip_list;
my $i = index ($zip_string, ',');
if ($i != -1) {
    @zip_list = split (',', $zip_string);
}
else {
    push (@zip_list, $zip_string);
}

#
# COLLECT DATA
# ============
#
my ($cases_list_ptr, $new_cases_hash_ptr, $new_case_serial_number) =
    byzip_collect::collect_data (
        \@date_dirs,
        $state,
        \@zip_list,
        $case_serial_number,
        $report_data_collection_messages,
        $pp_report_header_changes
    );
my @cases_list = @$cases_list_ptr;
my %new_cases_by_date = %$new_cases_hash_ptr;
$case_serial_number = $new_case_serial_number;

# my $debug_cases_list_ptr = byzip_debug::make_case_list (\@cases_list);
# my @debug_cases_list = @$debug_cases_list_ptr;

#
# ADD UNTESTED POSITIVES
# ======================
#
my $count = @cases_list;
if ($count == 0) {
    print ("List count is zero\n");
    exit (1);
}
my $untested_positive_case_count = 0;
my $temp_hash_ptr = $cases_list[0];
my $first_simulation_dt = $temp_hash_ptr->{'begin_dt'};
my $first_simulation_dt_epoch = $first_simulation_dt->epoch();

if ($untested_positive > 0) {
    print ("Adding untested positive cases...\n");

    for (my $i = 0; $i < $count; $i++) {
        my $existing_case_ptr = shift (@cases_list);

        #
        # Get info from an existing real case
        #
        my $existing_begin_dt = $existing_case_ptr->{'begin_dt'};
        my $existing_begin_epoch = $existing_begin_dt->epoch();
        my $zip_from_this_record = $existing_case_ptr->{'from_zip'};

        # my $change = DateTime::Duration->new (days => $i + 1);

        # my $new_begin_dt = $existing_begin_dt->clone();
        # $new_begin_dt->subtract_duration ($change);

        # my $diff = DateTime->compare ($new_begin_dt, $first_simulation_dt);
        my $dur_to_days = 86400;

        my $new_epoch = $existing_begin_epoch;
        my $number_of_days_to_backdate = 1;
        for (my $nc = 0; $nc < $untested_positive; $nc++) {
            #
            # Create info for a new untested case
            #
            my $t = $number_of_days_to_backdate * $dur_to_days;
            my $new_epoch = $new_epoch - $t;
            my $new_begin_dt = DateTime->from_epoch (epoch => $new_epoch);

            #
            # Do not create cases that pre-date the 1st real case
            #
            if ($new_epoch >= $first_simulation_dt_epoch) {
                #
                # Create a new cases
                #
                my %hash;

                $hash{'serial'} = $case_serial_number++;
                $hash{'begin_dt'} = $new_begin_dt;
                $hash{'from_zip'} = $zip_from_this_record;
                $hash{'untested_positive'} = 1;
                $hash{'sim_state'} = 'not started';

                # byzip_make_random_choices::add_random (
                #     \%hash,
                #     $duration_max,
                #     $duration_min,
                #     $report_data_collection_messages,
                #     $pp_report_adding_case);
                
                push (@cases_list, \%hash);

                $untested_positive_case_count++;
            }
            else {
                #
                # New case predates 1st real case so end this loop. Subsequent cases
                # will also predate
                #
                last;
            }

            $number_of_days_to_backdate -= 2;
        }
        
        push (@cases_list, $existing_case_ptr);
    }

    my @new_cases_list = sort case_sort_routine (@cases_list);
    @cases_list = @new_cases_list;
    $count = @cases_list;

    #
    # 
    #
    # ($last_serial, $largest_serial) = byzip_v::verify_case_list (\@cases_list);

    # $debug_cases_list_ptr = byzip_debug::make_case_list (\@cases_list);
    # @debug_cases_list = @$debug_cases_list_ptr;
}

#
# 
#
my ($last_serial, $largest_serial) = byzip_v::verify_case_list (\@cases_list);

print ("Have $count cases of which $untested_positive_case_count are untested positives\n");
print ("Last serial = $last_serial, largest = $largest_serial\n");

#
# SET UP MORTALITY VALUES
# =======================
#
# This creates a hash table with mortality rates for each date being simulated
#
my %mortality_table;
my ($mt_status, $mt_lookup_hash_ptr, $mortality_table_ptr) = byzip_mt::set_up_mortality_table (
    \%lookup_hash, \@date_dirs, $manually_set_mortality_rate);
if ($mt_status == 1) {
    %lookup_hash = %$mt_lookup_hash_ptr;
    %mortality_table = %$mortality_table_ptr;
}
else {
    die;
}

#
# DETERMINE FATAL CASES
# =====================
#
foreach my $case_hash_ptr (@cases_list) {
    my $case_begin_dt = $case_hash_ptr->{'begin_dt'};
    my $case_begin_date_string = sprintf ("%04d-%02d-%02d",
        $case_begin_dt->year(), $case_begin_dt->month(), $case_begin_dt->day());

    if (!(exists ($mortality_table{$case_begin_date_string}))) {
        print ("Sim date: $case_begin_date_string\n");
        print ("Mortality table does not have this key\n");
        die;
    }

    my $rate_x_10 = 10 * $mortality_table{$case_begin_date_string};
    my $random_mortality = int (rand (1000) + 1);
    if ($random_mortality <= $rate_x_10) {
        #
        # Case is fatal. Assume 5-10 days sick
        #
        my $span = 6;
        my $length_of_sickness_for_this_case = 5 + int (rand ($span) + 1);

        my $sickness_dur = DateTime::Duration->new (
            days        => $length_of_sickness_for_this_case);

        my $end_dt = $case_begin_dt->clone();
        $end_dt->add_duration ($sickness_dur);

        $case_hash_ptr->{'ending_status'} = 'dead';
        $case_hash_ptr->{'end_dt'} = $end_dt;
        $case_hash_ptr->{'severity'} = 'fatal';
    }
}

#
# PROCESS CASES
# =============
#
if ($pp_dont_do_sims) {
    print ("No sim done!!! \$pp_dont_do_sims flag is set!!!\n");
    exit (1);
}

print ("Begin simulation...\n");

my $cured_accum = 0;
my $sick_accum = 0;
my $untested_positive_accum = 0;
my $dead_accum = 0;
my @output_csv;
my $output_count;
my $output_header;

for (my $run_number = 1; $run_number <= $number_of_sims; $run_number++) {

    print ("*************** Sim $run_number *******************\n");

    foreach my $case_hash_ptr (@cases_list) {
        byzip_make_random_choices::add_random (
            $case_hash_ptr,
            $duration_max,
            $duration_min,
            $report_data_collection_messages,
            $pp_report_adding_case);
    }

    my $ptr = byzip_c::process (
        \@cases_list, 
        \%new_cases_by_date,
        $last_serial,
        $pp_report_sim_messages);
    my @this_run_output = @$ptr;

    #
    # One pass of the sim is complete, capture the last values
    #
    # Get the last csv record (row)
    #
    my $len = @this_run_output;
    my $last_record = $this_run_output[$len - 1];

    # print ("\$last_record = $last_record\n");

    #
    # Seperate the fields of the last record and add the 4 counts to the accumulators
    #
    my @seperated = split (',', $last_record);
    $cured_accum += $seperated[2];
    $sick_accum += $seperated[3];
    $untested_positive_accum += $seperated[4];
    $dead_accum += $seperated[5];

    if ($run_number == 1) {
        #
        # Initialize
        #
        $output_header = "Date,New,Cured,Sick,UntestedSick,Dead";
        @output_csv = @this_run_output;
        $output_count = @output_csv;
    }
    else {
        #
        # Add to what has been captured so far
        #
        $output_header .= ",Cured,Sick,UntestedSick,Dead";
        my @new_output_csv;
        for (my $j = 0; $j < $output_count; $j++) {
            #
            # Get the existing csv row and the new csv row from the sim just completed
            #
            my $existing = shift (@output_csv);
            my $new = shift (@this_run_output);

            #
            # Get everything except the date that is in the 1st column and
            # the new count in the second column
            #
            # "$t" should be ",n,n,n,n"
            #
            my $first_comma = index ($new, ',');
            my $second_comma = index ($new, ',', $first_comma + 1);
            my $t = substr ($new, $second_comma);
            # print ("\$t = $t\n");

            my $s = $existing .= $t;
            push (@new_output_csv, $s);
        }

        @output_csv = @new_output_csv;
    }
}

#
# CREATE OUTPUT CSV FILE
# ======================
#
my $output_file_name = $lookup_hash{'byzip_output_file'};
if (!(defined ($output_file_name))) {
    die "output_file_name not defined";
}

my $fully_qualified_output_file = "$dir/$output_file_name";
open (FILE, ">", $fully_qualified_output_file) or die "Can't open $fully_qualified_output_file: $!";
print (FILE "$output_header\n");

foreach my $r (@output_csv) {
    print (FILE "$r\n");
}

close (FILE);

#
# CREATE OUTPUT CHART FILE
# ========================
#
if ($plot_output_flag) {
    byzip_plot::make_plot (
        $dir,
        \@output_csv,
        $max_cured,
        $zip_string,
        $begin_display_dt);
}

#
#
#
print ("At end of simulation:\n");
print ("  Dead: " . int ($dead_accum / $number_of_sims) . "\n");
print ("  Cured: " . int ($cured_accum / $number_of_sims) . "\n");
print ("  Still sick " . int ($sick_accum / $number_of_sims) . "\n");
if ($untested_positive != 0) {
    print ("  Still sick from the untested positives " . int ($untested_positive_accum / $number_of_sims) . "\n");
}

exit (0);


###################################################################################
#
#
sub case_sort_routine {

    my $a_dt = $a->{'begin_dt'};
    my $b_dt = $b->{'begin_dt'};
    
    return (DateTime->compare ($a_dt, $b_dt));
}

sub make_printable_date_string {
    my $dt = shift;

    if (!(defined ($dt))) {
        goto graveyard;
    }

    my $string = sprintf ("%04d-%02d-%02d",
        $dt->year(), $dt->month(), $dt->day());

    return ($string);

graveyard:
    print ("Software error in make_printable_date_string(). Caller info:\n");
    my ( $package, $file, $line ) = caller();
    print ("  \$package = $package\n");
    print ("  \$file = $file\n");
    print ("  \$line = $line\n");
    exit (1);
}

sub choose_state {
    my $zip_string = shift;
    my $lookup_hash_ptr = shift;

    if (!(defined ($zip_string))) {
        print ("No zip code specified\n");
        exit (1);
    }
    else {
        print ("Setting up for zip code(s) $zip_string\n");
    }

    my $any_zip;
    my %lookup_hash = %$lookup_hash_ptr;

    my $i = index ($zip_string, ',');
    if ($i != -1) {
        $any_zip = substr ($zip_string, 0, $i);
    }
    else {
        $any_zip = $zip_string;
    }

    my $int_any_zip = int ($any_zip);
    if ($int_any_zip >= 10001 && $int_any_zip <= 11697) {
        return ('newyork', \%lookup_hash);
    }
    elsif ($int_any_zip >= 19101 && $int_any_zip <= 19197) {
        return ('pennsylvania', \%lookup_hash);
    }
    elsif ($int_any_zip >= 20601 && $int_any_zip <= 21921) {
        return ('maryland', \%lookup_hash);
    }
    elsif ($int_any_zip >= 27006 && $int_any_zip <= 28608) {
        return ('northcarolina', \%lookup_hash);
    }
    else {
        return ('florida', \%lookup_hash);
    }

    die;
}


#
# Return yes (1) or no (0)
#
# sub predict_case_is_fatal {
#     my $manually_set_mortality_rate_table_ptr = shift;
#     my $local_begin_dt = shift;

#     my $manually_set_mortality_rate;

#     if (1) {
#         my $key = main::make_printable_date_string ($local_begin_dt);
#         my $val = $manually_set_mortality_rate_table_ptr->{$key};
#         if (!(defined ($val))) {
#             print ("No value found in mortality hash table for $key\n");
#             exit (1);
#         }

#         $manually_set_mortality_rate = $val;
#     }
#     else {
#         $manually_set_mortality_rate = $fixed_mortality;
#     }

#     my $manually_set_mortality_rate_x_10 = int ($manually_set_mortality_rate * 10);

#     #
#     # Get a random value between 1 and 1000 inclusive
#     #
#     my $random_mortality = int (rand (1000) + 1);
#     if ($random_mortality <= $manually_set_mortality_rate_x_10) {
#         #
#         # Dies
#         #
#         return (1);
#     }
#     else {
#         #
#         # Lives
#         #
#         return (0);
#     }
# }


sub print_help {
    my ($min, $max) = @_;

    print ("\nByZip zip=nnnnn[,nnnnn] [additional switches]\n");

    print ("\n  zip=nnnnn\n");
    print ("    Required. May be multiple zips seperated by commas from a single state.\n");

    print ("\n  untested_positive=n[n]\n");
    print ("    Causes an additional n cases to be generated for each new reported case\n");
    print ("    These cases are shown in blue on the output graph. Default is zero.\n");


    print ("\n  cured_max_display=nnnnnnn\n");
    print ("    Limits the max number of cured cases shown on the output graph. Cured cases\n");
    print ("    generally greatly outnumber the other values presented on the graph. Cured\n");
    print ("    cases are shown in green on the graph. Default is currently zero. See line\n");
    print ("    $max_cured_line_number in ByZip.pl to modify the default value.\n");

    print ("\n  report_collection=[0/1]\n");
    print ("    Turns on debug output of the data collection from the .csv files. Default off (0)\n");

    print ("\n  duration_min=nn and duration_max=nn\n");
    print ("    The least/most number of days a person is sick. The random number generator\n");
    print ("    is used to select a value within the range. Current defaults are $min and $max days.\n");

    print ("\n  mortality=n.n\n");
    print ("    TBD..\n");

    print ("\n  first_sim_date=YYYY-MM-DD\n");
    print ("    Ordinarily, the first simulation date is determined by the first available date\n");
    print ("    directory. In a situation where there is no significant counts for a long period,\n");
    print ("    this switch will discard dates prior to what is specified. DO NOT use to reduce\n");
    print ("    chart display width. See README.md for details on false starts\n");

    print ("\n  first_display_date=YYYY-MM-DD\n");
    print ("    Sets the first date used in the display.\n");
}

#
# If a row value is wrapped in double quotes, remove the double quotes
# Sometimes row values are wrapped in double quotes but also contain commas
# These will not be changed
#
# Example:
#
#    ,"4" becomes 4
#    ,"tom, dick, harry", will be split into "tom
#                                             dick
#                                             harry"
#
sub remove_double_quotes_from_column_values {
    my $record = shift;

    my @list = split (',', $record);
    my $len = @list;
    for (my $i = 0; $i < $len; $i++) {
        my $val = $list[$i];
        if ($val =~ /^\"/ && $val =~ /\"\z/) {
            my $new_val = substr ($val, 1, length ($val) - 2);
            $list[$i] = $new_val;
        }
    }
    $record = join (',', @list);

    return ($record);
}

#
# If a field is wrapped in double quotes and it contains commas within the quotes,
# convert the commas to dashes and delete the double quotes
#
# This needs to be done prior to spliting the record or the commas will mess up the
# count of columns
#
sub remove_commas_from_double_quoted_column_values {
    my ($record) = @_;
    
    my $left_double_quote = index ($record, '"');
    if ($left_double_quote == -1) {
        return ($record);
    }

    my $right_double_quote = index ($record, '"', $left_double_quote + 1);
    if ($right_double_quote == -1) {
        print ("Record has a single double quote\n");
        exit (1);
    }

    my $len = $right_double_quote - $left_double_quote;
    my $temp = substr ($record, $left_double_quote + 1, $len - 1);

    # print ("  \$temp = $temp\n");

    $temp =~ s/, /-/g;
    $temp =~ s/,/-/g;

    my $left_half = substr ($record, 0, $left_double_quote);
    my $right_half = substr ($record, $right_double_quote + 1);

    return (remove_commas_from_double_quoted_column_values (
        $left_half . $temp . $right_half));
}

sub read_ini_file {

    my %lookup_hash;

    my $ini_file = 'local_lookup_settings.ini';
    my $general_section = 'general';
    my $data_processing_section = 'data processing';

    my $cfg = Config::IniFiles->new ( -file => $ini_file ) or die "Can't open $ini_file";

    $lookup_hash{'root'} = $cfg->val ($general_section, 'root');

    $lookup_hash{'newyork_root'} = lc $cfg->val ($general_section, 'newyork_root');
    $lookup_hash{'first_newyork_date_directory'} = $cfg->val ($general_section, 'first_newyork_date_directory');
    $lookup_hash{'newyork_source_repository'} = $cfg->val ($data_processing_section, 'newyork_source_repository');

    $lookup_hash{'florida_root'} = lc $cfg->val ($general_section, 'florida_root');
    $lookup_hash{'first_florida_date_directory'} = $cfg->val ($general_section, 'first_florida_date_directory');
    $lookup_hash{'florida_source_repository'} = $cfg->val ($data_processing_section, 'florida_source_repository');

    $lookup_hash{'maryland_root'} = lc $cfg->val ($general_section, 'maryland_root');
    $lookup_hash{'first_maryland_date_directory'} = $cfg->val ($general_section, 'first_maryland_date_directory');
    $lookup_hash{'maryland_source_repository'} = $cfg->val ($data_processing_section, 'maryland_source_repository');

    $lookup_hash{'northcarolina_root'} = lc $cfg->val ($general_section, 'northcarolina_root');
    $lookup_hash{'first_northcarolina_date_directory'} = $cfg->val ($general_section, 'first_northcarolina_date_directory');
    $lookup_hash{'northcarolina_source_repository_count'} = $cfg->val ($data_processing_section, 'northcarolina_source_repository_count');
    $lookup_hash{'northcarolina_source_repository_1'} = $cfg->val ($data_processing_section, 'northcarolina_source_repository_1');
    $lookup_hash{'northcarolina_source_repository_1_path_to_data'} = $cfg->val ($data_processing_section, 'northcarolina_source_repository_1_path_to_data');
    $lookup_hash{'northcarolina_source_repository_2'} = $cfg->val ($data_processing_section, 'northcarolina_source_repository_2');
    $lookup_hash{'northcarolina_source_repository_2_path_to_data'} = $cfg->val ($data_processing_section, 'northcarolina_source_repository_2_path_to_data');

    $lookup_hash{'pennsylvania_root'} = lc $cfg->val ($general_section, 'pennsylvania_root');
    $lookup_hash{'first_pennsylvania_date_directory'} = $cfg->val ($general_section, 'first_pennsylvania_date_directory');
    $lookup_hash{'pennsylvania_source_repository'} = $cfg->val ($data_processing_section, 'pennsylvania_source_repository');

    $lookup_hash{'byzip_output_file'} = $cfg->val ($general_section, 'byzip_output_file');




    return (\%lookup_hash);
}
