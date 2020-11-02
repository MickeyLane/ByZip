#!/usr/bin/perl
package byzip_setup_pennsylvania;
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
use PerlIO::gzip;

use lib '.';

sub setup_state {
    my $dir = shift;
    my $lookup_hash_ptr = shift;

    my @date_dirs;
    my $repository = $lookup_hash_ptr->{'pensylvania_source_repository'};

    opendir (DIR, $dir) or die "Can't open $dir: $!";
    while (my $fn = readdir (DIR)) {
        if ($fn =~ /^[.]/) {
            next;
        }
        
        if (-d "$dir/$fn") {


            if ($fn =~ /(\d{4})-(\d{2})-(\d{2})/) {
                push (@date_dirs, "$dir/$fn");

                #
                # ...\Maryland\YYYY-MM-DD found
                #
                my $destination_file = "$dir/$fn/converted.csv";
                my $source_file = "$repository/cases_by_zipcode/covid_cases_by_zip_$1-$2-$3.csv.gz";

                if (!(-e $destination_file)) {
                    #
                    # Destination not found
                    #
                    print ("Data file $destination_file is missing\n");

                    if (-e $source_file) {
                        convert_file ($source_file, $destination_file);
                        cleanup_pennsylvania_csv_files ($destination_file);
                    }
                    else {
                        print ("Can not find $source_file\n");
                    }
                }
            }
        }
    }

    closedir (DIR);

    return (\@date_dirs);
}

sub convert_file {
    my ($in, $out) = @_;

    print ("Converting data file...\n");
    print ("  In  $in\n");
    print (" Out  $out\n");

    #
    # Convert the .gz file to the .csv format in the destination directory
    #
    open (my $ifh, '<:gzip', $in) or die "Can't open input file: $!";
    open (my $ofh, '>:raw',  $out) or die "Can't create output file: $!";
    print $ofh $_ while <$ifh>;
    close $ifh or die $!;
    close $ofh or die $!;
}

#
# Fix issues in the .csv file
#
sub cleanup_pennsylvania_csv_files {
    my $in = shift;

    my @csv_records;
    my $record_number = 0;
    my $column_header_count;
    my @column_headers;
    my $expected_column_headers = 'zip_code,etl_timestamp,NEG,POS';
    my $out = $in;
    my $pos_column_number;
    my $neg_column_number;

    open (FILE, "<", $in) or die "Can't open $in: $!";
    while (my $record = <FILE>) {
        chomp ($record);
        $record_number++;

        if ($record_number == 1) {
            # if ($record ne $expected_column_headers) {
            #     print ("Unexpected column headers:\n");
            #     print ("  \$in = $in\n");
            #     print ("  \$expected_column_headers = $expected_column_headers\n");
            #     print ("  \$record = $record\n");
            #     exit (1);
            # }
            @column_headers = split (',', $record);
            $column_header_count = @column_headers;

            for (my $i = 0; $i < $column_header_count; $i++) {
                my $c = shift (@column_headers);
                if ($c eq 'POS') {
                    $pos_column_number = $i;
                }
                elsif ($c eq 'pos') {
                    $pos_column_number = $i;
                }
                if ($c eq 'NEG') {
                    $neg_column_number = $i;
                }
                elsif ($c eq 'neg') {
                    $neg_column_number = $i;
                }
            }

            push (@csv_records, $record);
            # push (@csv_records, "zip_code,etl_timestamp,neg,cases");
        }
        else {
            $record = main::remove_double_quotes_from_column_values ($record);
            $record = main::remove_commas_from_double_quoted_column_values ($record);
            my @values = split (',', $record);
            my $value_count = @values;

            if ($value_count != $column_header_count) {
                push (@values, '0');
            }

            if ($values[$neg_column_number] eq 'NA') {
                $values[$neg_column_number] = '0';
            }
            
            if ($values[$pos_column_number] eq 'NA') {
                $values[$pos_column_number] = '0';
            }
            
            $record = join (',', @values);
            push (@csv_records, $record);
        }
    }
    close (FILE);

    open (FILE, ">", $out) or die "Can't open $out: $!";
    foreach my $r (@csv_records) {
        print (FILE "$r\n");
    }
    close (FILE);

}

1;
