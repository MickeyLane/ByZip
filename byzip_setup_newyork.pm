#!/usr/bin/perl
package byzip_setup_newyork;
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

    # my $repository = $lookup_hash_ptr->{'newyork_source_repository'};

    my @fully_qualified_date_dirs;
    my @fully_qualified_diff_files;

    #
    # Make lists of the date dirs and the diff files, if they exist
    #
    opendir (DIR, $dir) or die "Can't open $dir: $!";
    while (my $fn = readdir (DIR)) {
        if ($fn =~ /^[.]/) {
            next;
        }
        
        if (-d "$dir/$fn") {
            if ($fn =~ /(\d{4})-(\d{2})-(\d{2})/) {
                push (@fully_qualified_date_dirs, "$dir/$fn");

                my $diff_file = "$dir/$fn/diff.txt";
                if (-e $diff_file) {
                    push (@fully_qualified_diff_files, $diff_file);
                }
            }
        }
    }

    closedir (DIR);

    my $d = @fully_qualified_date_dirs;
    my $f = @fully_qualified_diff_files;
    print ("Set up New York found $d directories and $f diff files\n");

    for (my $i = 1; $i < $d; $i++) {
        my $new_dir = $fully_qualified_date_dirs[$i];

        #
        # This will search the existing diff file list and if one that matches $new is found,
        # delete it and return the new (now shorter) diff file list.
        #
        my ($found, $ptr) = find_diff_file ($new_dir, \@fully_qualified_diff_files);
        if ($found) {
            @fully_qualified_diff_files = @$ptr;
            next;
        }

        my $new_data_file = "$new_dir/data-by-modzcta.csv";

        my $old_dir = $fully_qualified_date_dirs[$i - 1];
        my $old_data_file = "$old_dir/data-by-modzcta.csv";

        if (-e $new_data_file && -e $old_data_file) {
            compare_files ($old_data_file, $new_data_file);
        }
    }
}

sub compare_files {
    my ($old_fully_qualified_file_name, $new_fully_qualified_file_name) = @_;

    # print ("Converting data file...\n");
    # print ("  In  $in\n");
    # print (" Out  $out\n");

    my $diff_found_flag = 0;

    my $old_in_file_handle;
    my $new_in_file_handle;
    my $out_file_handle;
    my $record;

    my $i = rindex ($new_fully_qualified_file_name, '/');
    my $out = substr ($new_fully_qualified_file_name, 0, $i + 1) . 'diff.txt';

    #
    # Get the old file completely into memory
    #
    open ($old_in_file_handle, "<", $old_fully_qualified_file_name) or die "Can't open $old_fully_qualified_file_name: $!";
    my $old_file_header = <$old_in_file_handle>;
    my @old_file_contents;
    while ($record = <$old_in_file_handle>) {
        chomp ($record);
        push (@old_file_contents, $record);
    }
    close ($old_in_file_handle);

    #
    # Go through the new file record by record
    #
    open ($new_in_file_handle, "<", $new_fully_qualified_file_name) or die "Can't open $new_fully_qualified_file_name: $!";
    my $new_file_header = <$new_in_file_handle>;

    #
    # Create the output file
    #
    open ($out_file_handle, ">", $out) or die "Can't create $out: $!";
    print ($out_file_handle "Comparison between:\n");
    print ($out_file_handle "  Old: $old_fully_qualified_file_name\n");
    print ($out_file_handle "  New: $new_fully_qualified_file_name\n");
    
    my $old_zip_column;
    my $new_zip_column;
    my $old_cases_column;
    my $new_cases_column;
    if ($old_file_header eq $new_file_header) {
        print ($out_file_handle "Headers are the same\n");
        $old_zip_column = get_column_offset ($old_file_header, 'MODIFIED_ZCTA');
        if (!(defined ($old_zip_column))) {
            $old_zip_column = get_column_offset ($old_file_header, 'MODZCTA');
        }
        $new_zip_column = $old_zip_column;
        $old_cases_column = get_column_offset ($old_file_header, 'COVID_CASE_COUNT');
        if (!(defined ($old_cases_column))) {
            $old_cases_column = get_column_offset ($old_file_header, 'COVID_CASE_COUNT');
        }
        $new_cases_column = $old_cases_column;
    }
    else {
        print ($out_file_handle "Headers are different\n");
        die;
    }

    if (!(defined ($old_cases_column))) {
        print ("Can not locate case count column\n");
        print ("  File: $old_fully_qualified_file_name\n");
        print ("  Header: $old_file_header\n");
        die;
    }

    my @zips_changed_strings;
    my @zips_not_changed;
    while ($record = <$new_in_file_handle>) {
        chomp ($record);

        my @new_columns = split (',', $record);
        my $zip = $new_columns[$new_zip_column];

        my @old_columns;

        my ($found, $old_columns_ptr, $old_file_contents_ptr) = find_old_zip_record (\@old_file_contents, $old_zip_column, $zip);
        if ($found) {
            @old_file_contents = @$old_file_contents_ptr;
            @old_columns = @$old_columns_ptr;
        }
        else {
            print ($out_file_handle "Old file does not have a record for zip $zip. New does.\n");
            next;
        }

        #
        # A record from the new data file (i.e. current date) has been split into @new_columns
        # A record from the old file (i.e. the previous date) with a matching zip has been split
        # into @old_columns
        #
        if ($new_columns[$new_cases_column] eq $old_columns[$old_cases_column]) {
            push (@zips_not_changed, $zip);
        }
        else {
            $diff_found_flag = 1;

            my $ov = $old_columns[$old_cases_column];
            my $nv = $new_columns[$new_cases_column];
            my $delta = $nv - $ov;

            push (@zips_changed_strings, sprintf ("%s (%d)", $zip, $delta));
        }
    }

    add_zip_report ($out_file_handle, \@zips_not_changed, 'Zip codes not changed');
    add_zip_report ($out_file_handle, \@zips_changed_strings, 'Zip codes with changes');
    
    close ($new_in_file_handle);
    close ($out_file_handle);
}


sub find_old_zip_record {
    my ($old_file_content_ptr, $zip_column, $zip) = @_;

    my @old = @$old_file_content_ptr;
    my $c = @old;

    for (my $j = 0; $j < $c; $j++) {
        my $o = shift (@old);
        my @oc = split (',', $o);

        if ($zip eq $oc[$zip_column]) {
            return (1, \@oc, \@old);
        }
        else {
            push (@old, $o);
        }
    }

    return (0);
}

sub get_column_offset {
    my ($header, $col_name) = @_;

    my @columns = split (',', $header);
    my $c = @columns;
    for (my $i = 0; $i < $c; $i++) {
        if ($columns[$i] eq $col_name) {
            # print ("Found $col_name at offset $i\n");
            return $i;
        }
    }

    return (undef);
}

sub find_diff_file {
    my $new = shift;
    my $ptr = shift;

    my @diff_files = @$ptr;
    my $d = @diff_files;

    for (my $i = 1; $i < $d; $i++) {
        my $x = shift (@diff_files);
        if ($x eq $new) {
            return (1, \@diff_files);
        }
        else {
            push (@diff_files, $x);
        }
    }

    return (0, \@diff_files);
}


sub add_zip_report {
    my $out_file_handle = shift;
    my $list_ptr = shift;
    my $title_line = shift;

    my $line_len = 0;
    my $flag = 1;
    foreach my $z (@$list_ptr) {
        if ($flag) {
            my $string = "\n$title_line: $z";
            print ($out_file_handle $string);
            $line_len = length ($string);
            $flag = 0;
            next;
        }

        if ($line_len > 80) {
            print ($out_file_handle ", $z\n   ");
            $line_len = 3;
            next;
        }

        if ($line_len == 3) {
            print ($out_file_handle $z);
            $line_len += length ($z);
        }
        
        my $string = ", $z";
        print ($out_file_handle $string);
        $line_len += length ($string);
    }

    print ($out_file_handle "\n");
}

1;
