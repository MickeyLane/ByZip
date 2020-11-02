#!/usr/bin/perl
package byzip_zip_table;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use Cwd qw(cwd);
use POSIX;
use File::chdir;
use File::Basename qw(fileparse);
use File::Copy qw(move);

my $z_dir = 'D:\ByZip\ZipLookup';
my $in_out = "$z_dir/my_zip_code_database.csv";

sub zip_table_for_state {
    my $states_of_interest_ptr = shift;
    my $requested_state = shift;

    my $ifh;

    my @states_of_interest_from_caller = @$states_of_interest_ptr;
    my $count = @states_of_interest_from_caller;
    my $state_abbr;
    my $state_string;
    for (my $i = 0; $i < $count; $i += 2) {
        $state_abbr = $states_of_interest_from_caller[$i];
        $state_string = $states_of_interest_from_caller[$i + 1];

        if ($requested_state eq $state_string) {
            last;
        }
    }

    open ($ifh, "<", $in_out) or die "Can't open $in_out: $!";
    my $dont_need = <$ifh>;
    while (my $record = <$ifh>) {
        chomp ($record);
        
        my @fields = split (',', $record);

        my $state = $fields[6];
        if ($state_abbr ne $state) {
            next;
        }
        my $zip = $fields[0];
        my $pop = $fields[14];

    }
}

sub zip_table {
    my $states_of_interest_ptr = shift;

    my $in = "$z_dir/zip_code_database.csv";

    my %table_hash;
    my $record_number = 0;
    # my $header;
    my $ifh;
    my $ofh;
    #
    # Caller provides a list like:
    #
    #      PA
    #      pennsylvania
    #      NY
    #      newyork
    #
    # Strip out the PA, NY, etc
    #
    my @states_of_interest_from_caller = @$states_of_interest_ptr;
    my @states_of_interest_list;
    my $count = @states_of_interest_from_caller;
    for (my $i = 0; $i < $count; $i += 2) {
        push (@states_of_interest_list, $states_of_interest_from_caller[$i]);
    }

    open ($ofh, ">", $in_out) or die "Can't open $in_out: $!";
    open ($ifh, "<", $in) or die "Can't open $in: $!";
    while (my $record = <$ifh>) {
        $record_number++;
        chomp ($record);

        # zip,type,decommissioned,primary_city,   0-3
        # acceptable_cities,unacceptable_cities,state,county,  4-7
        # timezone,area_codes,world_region,country,    8-11
        # latitude,longitude,irs_estimated_population_2015    12-14
        #
        if ($record_number == 1) {
            # $header = $record;
            print ($ofh "$record\n");
        }
        else {
            $record = main::remove_commas_from_double_quoted_column_values ($record);

            my @fields = split (',', $record);

            if ($fields[1] eq 'PO BOX') {
                next;
            }

            if ($fields[1] eq 'UNIQUE') {
                next;
            }

            if ($fields[1] eq 'MILITARY') {
                next;
            }

            if ($fields[1] ne 'STANDARD') {
                print ("Field is $fields[1]\n");
                exit (1);
            }

            if ($fields[2] eq '1') {
                next;
            }

            my $zip = $fields[0];
            my $pop = $fields[14];

            #
            # States in the csv file are identified by the two-letter post office codes
            #
            my $state = $fields[6];

            my $flag = 0;
            foreach my $s (@states_of_interest_list) {
                if ($state eq $s) {
                    $flag = 1;
                }
            }

            if ($flag) {
            
                print ($ofh "$record\n");


            }
            else {
                next;
            }
            
        }
    }

    close ($ifh);
    close ($ofh);

}

1;

                #
                # The interest hash maps 'PA' to 'pennsylvania' but only if Pennsylvania
                # is a state of interest
                #
                # my $state_name = $states_of_interest_ptr->{$state};
                # if (exists ($table_hash{$state_name})) {
                #     #
                #     # The hash for this state has been started
                #     # Get the pointer to the state level hash
                #     #
                #     my $hash_ptr = $table_hash{$state_name};
                #     my $list_ptr = $hash_ptr->{'zip'};
                #     push (@$list_ptr, "$zip-$pop");
                # }
                # else {
                #     #
                #     # Make a new state level hash
                #     #
                #     my %hash;
                #     my @zip_list = "$zip-$pop";
                #     $hash{'zip'} = \@zip_list;
                #     # $hash{'pop'} = $pop;
                #     $table_hash{$state_name} = \%hash;
                # }


    # while (my ($key, $state_hash_ptr) = each %table_hash) {
    #     print ("$key\n");
    #     my $unsorted_zip_ptr = $state_hash_ptr->{'zip'};
    #     my @zips = sort (@$unsorted_zip_ptr);

    #     # my $pop = $state_hash_ptr->{'pop'};
    #     # print ("  Pop = $pop\n");

    #     my $line_count = 0;
    #     my $line;
    #     foreach my $z (@zips) {
    #         # if ($line_count == 0) {
    #         #     $line = "$z";
    #         #     $line_count = length ($line);
    #         # }
    #         # else {
    #         #     $line .= ", $z";
    #         #     $line_count = length ($line);
    #         # }

    #         # if ($line_count > 60) {
    #             print ("$z\n");
    #             # $line_count = 0;
    #         # }
    #     }
    # }
