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

use lib '.';
# use byzip_a;
use byzip_b;
use byzip_c;
use byzip_v;
use byzip_plot;
use byzip_debug;
use byzip_setup;
use byzip_mt;
use byzip_make_random_choices;

package main;

#
# Any variable that begins with 'fq_' is supposed to contain a fully qualified file name
# Any variable that begins with 'pp_' is a program parameter and is usually a flag to enable
#   or disable some feature
# Any variable that begins with 'fp_' is a floating point value. Not used very often
#

#
#
#
my $pp_covid_data_root_dir = 'D:/ByZip';
my $pp_create_missing_directories = 1;
my $pp_report_sim_messages = 0;
my $pp_report_adding_case = 0;
my $pp_dont_do_sims = 0;
my $pp_report_header_changes = 0;
my $pp_output_file_name = 'byzip-output.csv';

#
# OWID = Our World in Data at https://ourworldindata.org/coronavirus
#
my $pp_enable_use_of_owid_mortality_data = 1;
my $pp_owid_url = 'https://covid.ourworldindata.org/data/owid-covid-data.csv';
my $pp_mortality_hash_value_file_name = 'mort_hash.dat';
my $pp_print_mortality_table_and_exit = 0; # for debug or experimenting

my $now = DateTime->now;
my $todays_date_string_for_file_names = sprintf ("%04d %02d %02d",
                $now->year(),
                $now->month(),
                $now->day());

#
# MORTALITY
# =========
#
my $mortality = 3.1;
my %mortality_table;
if ($pp_enable_use_of_owid_mortality_data) {
    my $todays_owid_data_file_name = "$pp_covid_data_root_dir/$todays_date_string_for_file_names owid-covid-data.csv";
    my $todays_owid_usa_data_file_name = "$pp_covid_data_root_dir/$todays_date_string_for_file_names owid-usa-covid-data.csv";
    my $todays_mortality_data_file_name = "$pp_covid_data_root_dir/$todays_date_string_for_file_names $pp_mortality_hash_value_file_name";

    #
    # This creates "YYYY MM DD owid-covid-data.csv"
    #
    my $status = byzip_mt::get_mortality_records_from_server (
        $todays_owid_data_file_name,
        $pp_owid_url);
    if ($status != 1) {
        exit (1);
    }

    #
    # This creates "YYYY MM DD owid-usa_covid-data.csv" if necessary and returns the
    # content
    #
    my $us_csv_ptr = byzip_mt::get_usa_data (
        $todays_owid_data_file_name,
        $todays_owid_usa_data_file_name);

    byzip_mt::fill_mortality_hash (\%mortality_table, $us_csv_ptr, $todays_mortality_data_file_name);

    if ($pp_print_mortality_table_and_exit) {
        my @unsorted_records;
        while (my ($key, $val) = each %mortality_table) {
            push (@unsorted_records, "$key $val");
        }

        my @sorted_records = sort (@unsorted_records);

        foreach my $r (@sorted_records) {
            print ("$r\n");
        }

        exit (1);
    }
}

#
# ARGUMENTS
# =========
#
my $zip_string;
my $duration_min = 9;
my $duration_max = 19;
my $untested_positive = 0;
# my $non_white;
# my $white;
my $severity = '40:40:20';
my $plot_output_flag = 0;
my $max_cured = 0;
my $report_data_collection_messages = 0;  # default 'no'

my $untested_positive_switch = 'untested_positive=';
my $untested_positive_switch_string_len = length ($untested_positive_switch);

my $max_display_switch = 'cured_max_display=';
my $max_display_switch_string_len = length ($max_display_switch);

my $report_collection_switch = 'report_collection=';
my $report_collection_switch_string_len = length ($report_collection_switch);

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
        $mortality = substr ($switch, 10);
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
    # elsif (index ($lc_switch, 'non_white=') != -1) {
    #     my $val = substr ($switch, 10);
    #     $non_white = int ($val);
    # }
    else {
        print ("Don't know what to do with $switch\n");
        exit (1);
    }
}

my $state = choose_state ($zip_string);


print ("Simulation values:\n");
print ("  Zip = $zip_string\n");
print ("  State = $state\n");
if ($pp_enable_use_of_owid_mortality_data) {
    print ("  Mortality = using OWID derived table of daily percentage rates\n");
}
else {
    print ("  Mortality = $mortality percent\n");
}
print ("  Duration_min = $duration_min days\n");
print ("  Duration_max = $duration_max days\n");
print ("  Untested = add $untested_positive untested positive cases for every one detected\n");
# print ("  White = $white percent\n");
# print ("  Non_white = $non_white percent\n");
# print ("  Severity = $severity disease severity groups: no symptoms, moderate and severe\n");
# print ("      (Values are percents, total must be 100)\n");
print ("  Plot output = $plot_output_flag (0 = no, 1 = yes)\n");
print ("  Clip cured plot line at $max_cured. (Use $max_display_switch)\n");

my @csv_files;
# my $non_white_x_10 = int ($non_white * 10);

#
# SETUP
# =====
#
# Select state, pick directories, inventory directories, make missing directories
#
my ($status, $dir, $date_dirs_list_ptr) = byzip_setup::setup ($state, $pp_create_missing_directories);
if ($status == 0) {
    exit (1);
}

print ("Current working directory is $dir\n");

my @cases_list;
my %previous_cases_hash;
my $case_serial_number = 1;
my @date_dirs = @$date_dirs_list_ptr;

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
my $c = @date_dirs;
print ("Searching for .csv files in $c dirs and collecting data...\n");

#
# For each directory specified in dirs.txt, find a .csv file and save records that might be useful
#
my @suffixlist = qw (.csv .tsv);
foreach my $dir (@date_dirs) {
    if ($report_data_collection_messages) {
        print ("\n$dir...\n");
    }

    opendir (DIR, $dir) or die "Can't open $dir: $!";

    my $found_csv_file;

    while (my $rel_filename = readdir (DIR)) {
        #
        # Convert the found relative file name into a fully qualified name
        # If it turns out to be a subdirectory, ignore it
        #
        my $fq_filename = "$dir/$rel_filename";
        if (-d $fq_filename) {
            next;
        }

        my ($name, $path, $suffix) = fileparse ($fq_filename, @suffixlist);
        $path =~ s/\/\z//;

        if ($suffix eq '.csv') {
            # push (@csv_files, $fq_filename);
            # print ("$fq_filename\n");

            if (defined ($found_csv_file)) {
                print ("  There are multiple .csv files in $dir\n");
                exit (1);
            }

            $found_csv_file = $fq_filename;
        }
    }

    close (DIR);

    if (!(defined ($found_csv_file))) {
        if ($report_data_collection_messages) {
            print ("  No .csv file found in $dir\n");
        }
        next;
    }

    #
    # Get records reads the .csv file and returns a list of records that _might_ contain
    # useful information
    #
    my ($cases_column_offset, $zip_column_offset, $ptr) = get_records (
        $found_csv_file,
        \@zip_list,
        $state,
        $report_data_collection_messages,
        $pp_report_header_changes);

    my @possibly_useful_records = @$ptr;
    my $count = @possibly_useful_records;
    if ($count == 0) {
        print ("Fatal error. No possibly useful records found\n");
        print ("  \$cases_column_offset = $cases_column_offset\n");
        print ("  \$zip_column_offset = $zip_column_offset\n");
        exit (1);
    }
    elsif ($report_data_collection_messages) {
        print ("  Found $count possibly useful records\n");
    }

    #
    # Process possibly useful records, make list of useful records
    #
    $ptr = byzip_b::validate_records (
        $dir,
        \@possibly_useful_records,
        $cases_column_offset,
        $zip_column_offset,
        \@zip_list,
        $report_data_collection_messages);
    my @useful_records = @$ptr;
    $count = @useful_records;
    if ($count == 0) {
        print ("Fatal error. No useful records found\n");
        exit (1);
    }
    elsif ($report_data_collection_messages) {
        print ("  Found $count useful records\n");
    }

    #
    #
    #
    if ($report_data_collection_messages) {
        print ("    Process useful records...\n");
    }

    foreach my $record (@useful_records) {
        my @list = split (',', $record);

        #
        # Get the cases value
        #
        my $cases = $list[$cases_column_offset];
        my $zip_from_this_record = $list[$zip_column_offset];

        my $int_cases = int ($cases);
        # if ($negative_value_flag) {
        #     $int_cases = $int_cases * -1;
        # }

        if ($int_cases == 0) {
            next;
        }
        
        #
        # Determine new cases value
        #
        my $new_cases = 0;
        my $previous_cases = 0;
        if (exists ($previous_cases_hash{$zip_from_this_record})) {
            $previous_cases = $previous_cases_hash{$zip_from_this_record};
        }

        if ($previous_cases == 0) {
            #
            # First time a record has been found with 5 or more cases
            # so initialize $previous_cases
            #
            $new_cases = $int_cases;
            $previous_cases = $int_cases;
        }
        elsif ($previous_cases != $int_cases) {
            #
            # If cases from this record is not the same as previous cases, new
            # case records need to be generated
            #
            $new_cases = $int_cases - $previous_cases;
            $previous_cases = $int_cases;
        }

        $previous_cases_hash{$zip_from_this_record} = $previous_cases;

        #
        # Negative number of new cases. Someone at the health dept. twiddled the data.
        # Search previous cases for ones from this zip and delete them until the new
        # cases value is zero
        #
        if ($new_cases < 0) {
            my @cases_to_keep;
            while ($new_cases != 0) {
                my $cases_count = @cases_list;
                if ($cases_count == 0) {
                    print ("While attempting to delete cases due to a negative new case count, ran out of cases\n");
                    exit (1);
                }
                my $hash_ptr = pop (@cases_list);
                my $from_zip = $hash_ptr->{'from_zip'};
                if ($zip_from_this_record != $from_zip) {
                    push (@cases_to_keep, $hash_ptr);
                }
                else {
                    my $serial = $hash_ptr->{'serial'};
                    if ($report_data_collection_messages) {
                        print ("  Deleting case with serial = $serial\n");
                    }
                    $new_cases++;
                }
            }

            push (@cases_list, @cases_to_keep);

            next;
        }
        
        if ($new_cases == 0) {
            next;
        }

        #
        # Generate new cases
        # ------------------
        #
        if ($report_data_collection_messages) {
            print ("    New cases for $zip_from_this_record = $new_cases, total now $int_cases\n");
            print ("    \$dir = $dir\n");
        }

        if ($dir =~ /(\d{4})-(\d{2})-(\d{2})/) {
            my $begin_dt = DateTime->new(
                year       => $1,
                month      => $2,
                day        => $3
            );

            for (my $nc = 0; $nc < $new_cases; $nc++) {
                my %hash;
                $hash{'serial'} = $case_serial_number++;
                $hash{'begin_dt'} = $begin_dt;
                $hash{'from_zip'} = $zip_from_this_record;
                $hash{'sim_state'} = 'not started';

                # my $random_non_white = int (rand (1000) + 1);
                # if ($random_non_white <= $non_white_x_10) {
                #     $hash{'non_white'} = 1;
                # }
                # else {
                #     $hash{'non_white'} = 0;
                # }

                #
                # Add random values to case
                #
                byzip_make_random_choices::add_random (
                    \%hash,
                    $pp_enable_use_of_owid_mortality_data,
                    \%mortality_table,
                    $mortality,
                    $duration_max,
                    $duration_min,
                    $report_data_collection_messages,
                    $pp_report_adding_case);

                push (@cases_list, \%hash);
            }

        }
        else {
            print ("Can not determine date\n");
            exit (1);
        }
    }
        
    if ($report_data_collection_messages) {
        my $c = @cases_list;
        print ("    Case list count = $c\n");
    }
}

#
# 
#
my ($last_serial, $largest_serial) = byzip_v::verify_case_list (\@cases_list);

my $debug_cases_list_ptr = byzip_debug::make_case_list (\@cases_list);
my @debug_cases_list = @$debug_cases_list_ptr;

#
# ADD UNTESTED POSITIVES
# ======================
#
my $count = @cases_list;
my $untested_positive_case_count = 0;
my $temp_hash_ptr = $cases_list[0];
my $first_simulation_dt = $temp_hash_ptr->{'begin_dt'};
my $first_simulation_dt_epoch = $first_simulation_dt->epoch();;

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

                byzip_make_random_choices::add_random (
                    \%hash, $pp_enable_use_of_owid_mortality_data,
                    \%mortality_table, $mortality, $duration_max, $duration_min,
                    $report_data_collection_messages, $pp_report_adding_case);
                
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
    ($last_serial, $largest_serial) = byzip_v::verify_case_list (\@cases_list);

    $debug_cases_list_ptr = byzip_debug::make_case_list (\@cases_list);
    @debug_cases_list = @$debug_cases_list_ptr;
}


print ("Have $count cases of which $untested_positive_case_count are untested positives\n");
print ("Last serial = $last_serial, largest = $largest_serial\n");

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
my $number_of_sims = 3;
my @output_csv;
my $output_count;
my $output_header;

for (my $run_number = 1; $run_number <= $number_of_sims; $run_number++) {

    print ("*************** Sim $run_number *******************\n");

    foreach my $case_hash_ptr (@cases_list) {
        byzip_make_random_choices::add_random (
            $case_hash_ptr,
            $pp_enable_use_of_owid_mortality_data,
            \%mortality_table,
            $mortality,
            $duration_max, $duration_min,
            $report_data_collection_messages,
            $pp_report_adding_case);
    }

    my $ptr = byzip_c::process (\@cases_list, $last_serial, \@debug_cases_list, $pp_report_sim_messages);
    my @this_run_output = @$ptr;

    #
    # One pass of the sim is complete, capture the last values
    #
    # Get the last csv record (row)
    #
    my $len = @this_run_output;
    my $last_record = $this_run_output[$len - 1];

    #
    # Seperate the fields of the last record and add the 4 counts to the accumulators
    #
    my @seperated = split (',', $last_record);
    $cured_accum += $seperated[1];
    $sick_accum += $seperated[2];
    $untested_positive_accum += $seperated[3];
    $dead_accum += $seperated[4];

    if ($run_number == 1) {
        #
        # Initialize
        #
        $output_header = "Date,Cured,Sick,UntestedSick,Dead";
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
            # Get everything except the date that is in the 1st column
            # "$t" should be ",n,n,n,n"
            #
            my $first_comma = index ($new, ',');
            my $t = substr ($new, $first_comma);
            # print ("\$t = $t\n");

            my $s = $existing .= $t;
            push (@new_output_csv, $s);
        }

        @output_csv = @new_output_csv;
    }
}

my $output_file = "$dir/$pp_output_file_name";
open (FILE, ">", $output_file) or die "Can't open $output_file: $!";
print (FILE "$output_header\n");

foreach my $r (@output_csv) {
    print (FILE "$r\n");
}

close (FILE);

if ($plot_output_flag) {
    byzip_plot::make_plot ($dir, \@output_csv, $max_cured, $zip_string);
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

exit (1);


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

    my $string = sprintf ("%04d-%02d-%02d",
        $dt->year(), $dt->month(), $dt->day());

    return ($string);
}

sub choose_state {
    my $zip_string = shift;

    if (!(defined ($zip_string))) {
        print ("No zip code specified\n");
        exit (1);
    }

    my $any_zip;

    my $i = index ($zip_string, ',');
    if ($i != -1) {
        $any_zip = substr ($zip_string, 0, $i);
    }
    else {
        $any_zip = $zip_string;
    }

    my $int_any_zip = int ($any_zip);
    if ($int_any_zip >= 10001 && $int_any_zip <= 11697) {
        return ('newyork');
    }
    elsif ($int_any_zip >= 20601 && $int_any_zip <= 21921) {
        return ('maryland');
    }
    else {
        return ('florida');
    }
}


#
# Given a file name and a list of zip code strings, return any record (row) that
# contains anything string of characters that might be a zip code
#
# While looking at the 1st record, find the offsets (column numbers) for various
# items of interest
#
sub get_records {
    my $found_csv_file = shift;
    my $zip_list_ptr = shift;
    my $state = shift;
    my $report_data_collection_messages = shift;
    my $report_header_changes = shift;

    my $record_number = 0;
    my $header_string;
    my @header_list;
    my $cases_column_offset;
    my $zip_column_offset;
    my $reference_header_string;
    my @reference_header_list;
    my @possibly_useful_records;

    if ($report_data_collection_messages) {
        print ("  get_records() is using:\n");
        foreach my $zip_to_test (@$zip_list_ptr) {
            print ("    $zip_to_test\n");
        }
    }

    open (FILE, "<", $found_csv_file) or die "Can't open $found_csv_file: $!";
    while (my $record = <FILE>) {
        $record_number++;
        chomp ($record);

        if ($record_number == 1) {
            my $changed_flag = 0;
            my $initial_flag = 0;

            #
            # Remove BOM if any
            #
            if ($record =~ /^\xef\xbb\xbf/) {
                $header_string = substr ($record, 3);
            }
            elsif ($record =~ /^\xfe\xff\x00\x30\x00\x20\x00\x48\x00\x45\x00\x41\x00\x44/) {
                print ("  File is Unicode\n");
                die;
            }
            else {
                $header_string = $record;
            }

            if (!(defined ($reference_header_string))) {
                $reference_header_string = $header_string;
                @reference_header_list = split (',', $header_string);
                $initial_flag = 1;
            }

            if ($header_string ne $reference_header_string) {
                $reference_header_string = $header_string;
                @reference_header_list = split (',', $header_string);
                undef ($zip_column_offset);
                undef ($cases_column_offset);
                $changed_flag = 1;
            }

            my $len = @reference_header_list;
            for (my $j = 0; $j < $len; $j++) {
                my $h = lc $reference_header_list[$j];
                if ($h eq 'cases_1') {
                    $cases_column_offset = $j;
                }
                elsif ($h eq 'cases') {
                    $cases_column_offset = $j;
                }
                elsif ($h eq 'covid_case_count') {
                    $cases_column_offset = $j;
                }
                elsif ($h eq 'positive') {
                    $cases_column_offset = $j;
                }
                elsif ($h eq 'zip') {
                    $zip_column_offset = $j;
                }
                elsif ($h eq 'zipx') {
                    $zip_column_offset = $j;
                }
                elsif ($h eq 'modified_zcta') {
                    $zip_column_offset = $j;
                }
                elsif ($h eq 'modzcta') {
                    $zip_column_offset = $j;
                }
            }

            if (!(defined ($zip_column_offset))) {
                print ("Zip column offset not discovered in header\n");
                print ("  Have:\n");
                foreach my $h (@reference_header_list) {
                    print ("    $h\n");
                }
                exit (1);
            }

            if ($report_data_collection_messages && $report_header_changes) {
                if ($changed_flag) {
                    print ("  Header change:\n");
                    print ("    'cases_1' offset is $cases_column_offset\n");
                    print ("    'zip' offset is $zip_column_offset\n");
                }
                elsif ($initial_flag) {
                    print ("  Initial header:\n");
                    print ("    'cases_1' offset is $cases_column_offset\n");
                    print ("    'zip' offset is $zip_column_offset\n");
                }
            }

            next;
        }
        
        #
        # Search for any instance of any of the zipcode string characters
        # Could be part of some totally unrelated number
        #
        my $found_zip_like_string = 0;
        foreach my $zip_to_test (@$zip_list_ptr) {
            my $j = index ($record, $zip_to_test);
            if ($j != -1) {
                # print ("  Found $zip_to_test in \"$record\"\n");
                $found_zip_like_string = 1;
                # last;
            }
            else {
                # print ("  Did not find $zip_to_test in \"$record\"\n");
            }
        }

        if ($found_zip_like_string == 0) {
            next;
        }

        # print ("  Saving \"$record\"\n");
        push (@possibly_useful_records, $record);
    }

    close (FILE);

    if (!(defined ($cases_column_offset))) {
        print ("The cases number column offset was not discovered\n");
        exit (1);
    }
    if (!(defined ($zip_column_offset))) {
        print ("The zip code column offset was not discovered\n");
        exit (1);
    }
    
    return ($cases_column_offset, $zip_column_offset, \@possibly_useful_records);
}
