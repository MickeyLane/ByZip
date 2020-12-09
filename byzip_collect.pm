#!/usr/bin/perl
package byzip_collect;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use File::Find;           
use File::chdir;
use File::Basename;
use Scalar::Util qw(looks_like_number);

sub collect_data {
    my $date_dirs_ptr = shift;
    my $state = shift;
    my $zip_list_ptr = shift;
    my $case_serial_number = shift;
    my $report_data_collection_messages = shift;
    my $report_header_changes = shift;

    my @fully_qualified_date_dir_list = @$date_dirs_ptr;
    my @zip_list = @$zip_list_ptr;

    my %new_cases_by_date_hash;
    my %previous_cases_hash;
    my @cases_list;

    my $c = @fully_qualified_date_dir_list;
    print ("Searching for .csv files in $c dirs and collecting data...\n");

    #
    # For each directory specified in dirs.txt, find a .csv file
    # and save records that might be useful
    #
    my @suffixlist = qw (.csv);
    foreach my $fully_qualified_date_dir (@fully_qualified_date_dir_list) {
        if ($report_data_collection_messages) {
            print ("\n$fully_qualified_date_dir...\n");
        }

        opendir (DIR, $fully_qualified_date_dir) or die "Can't open $fully_qualified_date_dir: $!";

        my $found_csv_file;

        while (my $rel_filename = readdir (DIR)) {
            #
            # Convert the found relative file name into a fully qualified name
            # If it turns out to be a subdirectory, ignore it
            #
            my $fully_qualified_file_name = "$fully_qualified_date_dir/$rel_filename";
            if (-d $fully_qualified_file_name) {
                next;
            }

            my ($name, $path, $suffix) = fileparse ($fully_qualified_file_name, @suffixlist);
            $path =~ s/\/\z//;

            if ($suffix eq '.csv') {
                if (defined ($found_csv_file)) {
                    print ("  There are multiple .csv files in $fully_qualified_date_dir\n");
                    exit (1);
                }

                $found_csv_file = $fully_qualified_file_name;
            }
        }

        close (DIR);

        if (!(defined ($found_csv_file))) {
            if ($report_data_collection_messages) {
                print ("  No .csv file found in $fully_qualified_date_dir\n");
            }
            next;
        }

        #
        # Get records reads the .csv file and returns a list of records that _might_ contain
        # useful information
        #
        my ($cases_column_offset, $zip_column_offset, $ptr) = get_possibly_useful_records (
            $found_csv_file,
            \@zip_list,
            $state,
            $report_data_collection_messages,
            $report_header_changes);

        my @possibly_useful_records = @$ptr;
        my $count = @possibly_useful_records;
        if ($count == 0) {
            print ("No possibly useful records found\n");
            print ("  \$found_csv_file = $found_csv_file\n");
            print ("  \$cases_column_offset = $cases_column_offset\n");
            print ("  \$zip_column_offset = $zip_column_offset\n");
            # exit (1);
            next;
        }
        elsif ($report_data_collection_messages) {
            print ("  Found $count possibly useful records\n");
        }

        #
        # Process possibly useful records, make list of useful records
        #
        $ptr = validate_possibly_useful_records (
            $fully_qualified_date_dir,
            $found_csv_file,
            \@possibly_useful_records,
            $cases_column_offset,
            $zip_column_offset,
            \@zip_list,
            $report_data_collection_messages);
        my @useful_records = @$ptr;
        $count = @useful_records;
        if ($count == 0) {
            # print ("Fatal error. No useful records found\n");
            # exit (1);
            next;
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
                my $cases_to_delete_count = $new_cases * -1;
                my ($ptr, $new_serial) = byzip_delete_cases::delete_cases_from_list (
                    \@cases_list, $cases_to_delete_count, $zip_from_this_record,
                    $case_serial_number, $report_data_collection_messages);
                @cases_list = @$ptr;
                $case_serial_number = $new_serial;
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
                print ("    \$fully_qualified_date_dir = $fully_qualified_date_dir\n");
            }

            if ($fully_qualified_date_dir =~ /(\d{4})-(\d{2})-(\d{2})/) {
                my $begin_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3
                );

                #
                # Log new cases for the date. Note fully qualified vs relitive.
                #
                my $i = rindex ($fully_qualified_date_dir, '/');
                my $date_dir = substr ($fully_qualified_date_dir, $i + 1);
                $new_cases_by_date_hash{$date_dir} = $new_cases;
                print ("New cases for $date_dir = $new_cases\n");

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
                    # byzip_make_random_choices::add_random (
                    #     \%hash,
                    #     $duration_max,
                    #     $duration_min,
                    #     $report_data_collection_messages,
                    #     $pp_report_adding_case);

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

    return (\@cases_list, \%new_cases_by_date_hash, $case_serial_number);
}

#
# Given a file name (...csv) and a list of zip code strings, return any record (row) that
# contains any string of characters that might be one of the zip codes
#
# While looking at the 1st record, find the offsets (column numbers) for various
# items of interest
#
sub get_possibly_useful_records {
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
        print ("  get_possibly_useful_records() is using:\n");
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
                elsif ($h eq 'pos') {
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
                elsif ($h eq 'zip_code') {
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
                elsif ($h eq 'zipcode') {
                    $zip_column_offset = $j;
                }
            }

            if (!(defined ($zip_column_offset)) || !(defined ($cases_column_offset))) {
                if (!(defined ($cases_column_offset))) {
                    print ("Cases column offset not discovered in header\n");
                }
                else {
                    print ("Zip column offset not discovered in header\n");
                }
                print ("  Found the columns: (double quotes added)\n");
                foreach my $h (@reference_header_list) {
                    print ("    \"$h\"\n");
                }
                print ("  File: $found_csv_file\n");
                if (defined ($cases_column_offset)) {
                    print ("  Cases column offset is $cases_column_offset\n");
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

    # if (!(defined ($cases_column_offset))) {
    #     print ("The cases number column offset was not discovered\n");
    #     exit (1);
    # }
    # if (!(defined ($zip_column_offset))) {
    #     print ("The zip code column offset was not discovered\n");
    #     exit (1);
    # }
    
    return ($cases_column_offset, $zip_column_offset, \@possibly_useful_records);
}

sub validate_possibly_useful_records {
    my $fully_qualified_date_dir = shift;
    my $csv_file_name = shift;
    my $ptr = shift;
    my $cases_column_offset = shift;
    my $zip_column_offset = shift;
    my $zip_list_ptr = shift;
    my $make_debug_print_statements = shift;

    # my $make_debug_print_statements = 1;   # VSC debugger is broken :-(

    my @possibly_useful_records = @$ptr;
    my @useful_records;

    foreach my $record (@possibly_useful_records) {
        if ($make_debug_print_statements) {
            # print ("$fully_qualified_date_dir...\n");
            print ("  \$record = $record\n");
        }

        $record = main::remove_double_quotes_from_column_values ($record);

        $record = main::remove_commas_from_double_quoted_column_values ($record);

        my @list = split (',', $record);

        my $this_zip = $list[$zip_column_offset];
        if ($make_debug_print_statements) {
            print ("  \$this_zip = $this_zip\n");
        }

        #
        # Zips can be given as 'Hillsborough-33540' or '"27016"' etc.
        # Only the 5 digits are of interest
        # Replace the column value with just the 5 digits below
        #
        my $zip_from_this_record;
        my $zip_is_good = 0;
        if ($this_zip =~ /(\d{5})/) {
            $zip_from_this_record = $1;
            foreach my $zip_to_test (@$zip_list_ptr) {
                if ($zip_to_test == $zip_from_this_record) {
                    $zip_is_good = 1;
                    # last;
                }
            }
        }

        if (!$zip_is_good) {
            next;
        }

        my $cases = $list[$cases_column_offset];
        if (!(defined ($cases))) {
            if ($make_debug_print_statements) {
                print ("Did not extract any value for cases\n");
                print ("  File: $csv_file_name\n");
                print ("  \$cases_column_offset = $cases_column_offset\n");
                print ("  \$record = \"$record\"\n");
            }
                # exit (1);
            next;
        }

        if ($make_debug_print_statements) {
            print ("  \$cases = $cases\n");
        }

        if (length ($cases) eq 0) {
            print ("  Null cases column found at offset $cases_column_offset\n");
            exit (1);
        }

        #
        # If cases equal zero, ignore
        #
        if ($cases eq '0') {
            next;
        }

        #
        # If the 1st char is '<5', make 0
        # If '5 to 9', make 7
        # If something other than a simple number, complain
        #
        if ($cases eq '<5') {
            $cases = '0';
        }
        elsif ($cases eq '5 to 9') {
            # print ("  Changing '5 to 9' to 7\n");
            $cases = '7';
        }
        elsif (!(looks_like_number($cases))) {
            print ("  Non numeric found in cases field is $cases\n");
            exit (1);
        }

        #
        # Test for a negative value string. Probably not found anywhere
        #
        # my $negative_value_flag = 0;
        # if ($first_cases_character eq '-') {
        #     $negative_value_flag = 1;
        #     my $new_cases_string = substr ($cases, 1);
        #     $cases = $new_cases_string;
        #     print ("Negative value found in cases column\n");
        #     exit (1);
        # }

        #
        # Update fields and make a new record
        #
        $list[$cases_column_offset] = $cases;
        $list[$zip_column_offset] = $zip_from_this_record;
        my $new_record = join (',', @list);
        push (@useful_records, $new_record);
    }

    return (\@useful_records);
}

1;
