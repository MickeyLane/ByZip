#!/usr/bin/perl
package byzip_mt;
use warnings;
use strict;

use LWP::Simple;

#
# This file is part of byzip.pl. See information at the top of that file
#

#####################################################################################
#
# The mortality table is a hash:
#
#    Key:  The date in the format YYYY-MM-DD
#   Value:  A floating point value representing the mortality rate on that date
#
# If the manually set mortality rate is set on the command line, all values are the
# same. If not, the OWID file is used to select a value for the date. The value represents
# the entire country.
#
sub set_up_mortality_table {
    my $lookup_hash_ptr = shift;
    my $data_dirs_being_used_list_ptr = shift;
    my $manually_set_mortality_rate = shift;

    #
    # Get the lookup hash. Modifications made to this (if any) will be propagated
    # back to the original table in the main module
    #
    my %local_lookup_hash = %$lookup_hash_ptr;

    #
    # Dates to be simulated have already been determined. Incomming list is
    # fully qualified path names. Convert to just the dir name.
    # Get 1st and last
    #
    my @data_dirs_being_used_list;
    foreach my $dd (@$data_dirs_being_used_list_ptr) {
        my $i = rindex ($dd, '/');
        push (@data_dirs_being_used_list, substr ($dd, $i + 1));
    }
    my $count = @data_dirs_being_used_list;

    my $begin_dt;
    my $end_dt;
    my $first_date_for_table = $data_dirs_being_used_list[0];
    if ($first_date_for_table =~ /(\d{4})-(\d{2})-(\d{2})/) {
        $begin_dt = DateTime->new(
            year       => $1,
            month      => $2,
            day        => $3
        );
    }
    else {
        die "Bad date format for begin date";
    }
    my $last_date_for_table = $data_dirs_being_used_list[$count - 1];
    if ($last_date_for_table =~ /(\d{4})-(\d{2})-(\d{2})/) {
        $end_dt = DateTime->new(
            year       => $1,
            month      => $2,
            day        => $3
        );
    }
    else {
        die "Bad date format for end date";
    }

    my %mortality_table;
    my $status;

    #
    # Two options:
    #
    #    1) Manually specified mortality rate = make table with same value for each date
    #    2) No specified rate = get OWID file and make table with values specified
    #
    if ($manually_set_mortality_rate == 0) {

        my $root = $local_lookup_hash{'root'};
        if (!(defined ($root))) {
            die "'root' is not defined in the lookup hash";
        }

        my $todays_date_string_for_file_names = $local_lookup_hash{'todays_date_string'};
        my $todays_owid_data_file_name = "$root/$todays_date_string_for_file_names owid-covid-data.csv";
        my $todays_owid_usa_data_file_name = "$root/$todays_date_string_for_file_names owid-usa-covid-data.csv";

        $status = get_mortality_records_from_server ($todays_owid_data_file_name);
        if ($status == 0) {
            #
            # Error
            #
            return (0);
        }
        elsif ($status == 2) {
            #
            # New file downloaded
            #
            print ("Making extracted USA record file...\n");

            strip_owid_data (
                $todays_owid_data_file_name,
                $todays_owid_usa_data_file_name);
        }
        else {
            #
            # File already exists
            #
        }

        print ("  Reading file with extracted USA records\n");

        my $date_col = 3;
        my $total_case = 4;
        my $total_death = 7;

        # my @r;
        my $record_number = 0;
        open (FILE, "<", $todays_owid_usa_data_file_name) or die "Can't open $todays_owid_usa_data_file_name: $!";
    
        my $column_header = <FILE>;

        while (my $record = <FILE>) {
            $record_number++;
            chomp ($record);

            my @columns = split (',', $record);

            my $date_str = $columns[$date_col];
            my $from_file_dt;
            if ($date_str =~ /(\d{4})-(\d{2})-(\d{2})/) {
                $from_file_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3
                );
            }
            else {
                print ("Bad date field in OWID USA file");
                print ("  \$record = $record\n");
                print ("  \$date_col = $date_col\n");
                print ("  \$date_str = $date_str\n");
                die;
            }

            if ($from_file_dt < $begin_dt) {
                next;
            }

            my $deaths = $columns[$total_death];
            my $cases = $columns[$total_case];
            
            if ($deaths eq '' || $cases eq '') {
                $mortality_table{$date_str} = 0;
                next;
            }

            #
            # Compute the percentage. Result is a floating point number
            #
            $mortality_table{$date_str} = (int ($deaths)/ int ($cases)) * 100;
        }

        close (FILE);

        $status = 1;
    }
    else {
        print ("Setting up mortality table from fixed value specified on command line...\n");

        foreach my $d (@data_dirs_being_used_list) {
            # print ("  \$d = $d\n");
            $mortality_table{$d} = $manually_set_mortality_rate;
        }

        $status = 1;
    }

    # save_mortality_table_to_file (\%mortality_table);

    return ($status, \%local_lookup_hash, \%mortality_table);
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
}

#
#
#
sub get_mortality_records_from_server {
    my $todays_owid_data_file_name = shift;

    print ("Downloading OWID mortality data...\n");

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
            return (2);
        }
        else {
            print ("  Getstore response code $code\n");
            return (0);
        }
    }
    else {
        print ("  Today's OWID file already exists\n");
        return (1);
    }
}

sub save_mortality_table_to_file {
    my $mortality_table_ptr = shift;

    my @pre_sort = keys %$mortality_table_ptr;
    my @sorted = sort @pre_sort;

    my $fn = 'mortality_table.csv';

    open (FILE, ">", $fn) or die "Can't create $fn: @!";

    foreach my $key (@sorted) {
        my $val = $mortality_table_ptr->{$key};

        print (FILE "$key = $val\n");
    }

    close (FILE);
}

1;
