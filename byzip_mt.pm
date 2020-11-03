#!/usr/bin/perl
package byzip_mt;
use warnings;
use strict;

use LWP::Simple;

#
# This file is part of byzip.pl. See information at the top of that file
#

#
#
#
sub get_mortality_records_from_server {
    my $lookup_hash_ptr = shift;
    my $date_dirs_list_ptr = shift;

    print ("OWID mortality data...\n");

    my %local_lookup_hash = %$lookup_hash_ptr;

    my $root = $local_lookup_hash{'root'};
    if (!(defined ($root))) {
        print ("'root' is not defined in the lookup hash\n");
        exit (1);
    }
    my $todays_date_string_for_file_names = $local_lookup_hash{'todays_date_string'};
    my $todays_owid_data_file_name = "$root/$todays_date_string_for_file_names owid-covid-data.csv";
    my $todays_owid_usa_data_file_name = "$root/$todays_date_string_for_file_names owid-usa-covid-data.csv";

    #
    # See if the file already exists. If not, get it
    #
    if (!(-e $todays_owid_data_file_name)) {
        my $owid_url = 'https://covid.ourworldindata.org/data/owid-covid-data.csv';
        #
        # Get the world-wide file from the server
        #
        print ("  Retreiving today's OWID data...\n");
        my $code = getstore ($owid_url, $todays_owid_data_file_name);
        if ($code == 200) {
            print ("  Success\n");
        }
        else {
            print ("  Getstore response code $code\n");
            return (0);
        }
    }
    else {
        print ("  Today's OWID file already exists\n");
    }

    #
    # This creates "YYYY MM DD owid-usa_covid-data.csv" if necessary and returns the
    # content
    #
    my $us_csv_ptr = get_usa_data (
        $todays_owid_data_file_name,
        $todays_owid_usa_data_file_name);

    my $ptr = fill_mortality_hash ($us_csv_ptr);
    my %mortality_table = %$ptr;

    # if ($print_mortality_table_and_exit) {
    #     my @unsorted_records;
    #     while (my ($key, $val) = each %mortality_table) {
    #         push (@unsorted_records, "$key $val");
    #     }

    #     my @sorted_records = sort (@unsorted_records);

    #     foreach my $r (@sorted_records) {
    #         print ("$r\n");
    #     }

    #     exit (1);
    # }

    return (1, \%local_lookup_hash, \%mortality_table);
}

sub get_usa_data {
    my $todays_owid_data_file_name = shift;
    my $todays_owid_usa_data_file_name = shift;

    my $us_csv_ptr;

    if (-e $todays_owid_usa_data_file_name) {
        #
        # File exists. Read it
        #
        print ("  Reading existing file with extracted USA records\n");

        my @r;
        my $record_number = 0;
        open (FILE, "<", $todays_owid_usa_data_file_name) or die "Can't open $todays_owid_usa_data_file_name: $!";
        while (my $record = <FILE>) {
            $record_number++;
            chomp ($record);

            push (@r, $record);
        }

        $us_csv_ptr = \@r;
    }
    else {
        #
        # File does not exist. Extract USA data
        #
        print ("Making extracted USA record file...\n");

        $us_csv_ptr = strip_owid_data (
            $todays_owid_data_file_name,
            $todays_owid_usa_data_file_name);
    }

    return ($us_csv_ptr);
}

sub fill_mortality_hash {
    my $csv_ptr = shift;

    my %mortality_table;

    my $column_header = shift (@$csv_ptr);

    #
    # Process records in $csv_ptr
    #
    my $date_col = 3;
    my $total_case = 4;
    my $total_death = 7;
    foreach my $r (@$csv_ptr) {
        my @list = split (',', $r);

        my $date_original_str = $list[$date_col];
        #
        # The date string format in the csv file os OK
        #
        # my $data_my_str = convert_date_format ($date_original_str);
        my $data_my_str = $date_original_str;

        if ($list[$total_death] eq '' || $list[$total_case]) {
            $mortality_table{$data_my_str} = 0;
            next;
        }

        my $deaths = int ($list[$total_death]);
        my $cases = int ($list[$total_case]);

        #
        # Compute the percentage. Result is a floating point number
        #
        $mortality_table{$data_my_str} = ($deaths/ $cases) * 100;
    }

    return (\%mortality_table);
}

sub convert_date_format {
    my $date_original_str = shift;

    if ($date_original_str =~ /(\d{4})-(\d{2})-(\d{2})/) {
        my $date = "$1 $2 $3";
        return ($date);
    }
    else {
        print ("Unexpected format given to convert_date_format\n");
        exit (1);
    }
}

sub strip_owid_data {
    my ($in, $out) = @_;

    my @out_data;
    my $record_number = 0;
    my $header_string;

    open (FILE, "<", $in) or die "Can't open $in: $!";
    while (my $record = <FILE>) {
        $record_number++;
        chomp ($record);

        if ($record_number == 1) {
            #
            # Remove BOM if any
            #
            if ($record =~ /^\xef\xbb\xbf/) {
                print ("File has BOM\n");
                $header_string = substr ($record, 3);
            }
            elsif ($record =~ /^\xfe\xff\x00\x30\x00\x20\x00\x48\x00\x45\x00\x41\x00\x44/) {
                print ("  File is Unicode\n");
                die;
            }
            else {
                $header_string = $record;
            }

            my $i = index ($record, ',');
            my $first_column_label = substr ($record, 0, $i);

            if ($first_column_label ne 'iso_code') {
                print ("Unexpected first column of header record is $first_column_label\n");
                exit (1);
            }

            next;
        }

        if ($record =~ /^USA/) {
            push (@out_data, $record);
        }
    }

    close (FILE);

    open (FILE, ">", $out) or die "Can't open $out: $!";
    print (FILE "$header_string\n");
    foreach my $r (@out_data) {
        print (FILE "$r\n");
    }

    close (FILE);

    return (\@out_data);
}

1;
