#!/usr/bin/perl
package byzip_cleanups;
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
# This needs to be done prior to the split below or the commas will mess up the
# count of columns for the record
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

#
#
#
#
sub cleanup_northcarolina_csv_files {
    my ($in, $out) = @_;

    my @csv_records;
    my $record_number = 0;
    my $column_header_count;
    my @column_headers;

    open (FILE, "<", $in) or die "Can't open $in: $!";
    while (my $record = <FILE>) {
        chomp ($record);
        $record_number++;

        if ($record_number == 1) {
            @column_headers = split (',', $record);
            $column_header_count = @column_headers;
            push (@csv_records, $record);
        }
        else {
            $record = remove_double_quotes_from_column_values ($record);
            $record = remove_commas_from_double_quoted_column_values ($record);
            my @values = split (',', $record);
            my $value_count = @values;
            if ($value_count != $column_header_count) {
                push (@values, "<5");
            }

            if ($column_headers[0] eq 'Shape__Length') {
                $values[0] = 0;
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

    unlink ($in) or die "Can't delete $in: $!";
}

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
            # $record = remove_double_quotes_from_column_values ($record);
            # $record = remove_commas_from_double_quoted_column_values ($record);
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
