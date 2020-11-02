#!/usr/bin/perl
package byzip_setup_northcarolina;
use warnings FATAL => 'all';
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
    my $dir_handle;
    
    print ("Set up North Carolina...\n");

    #
    # $dir should be something like D:/ByZip/NorthCarolina
    # That dir should contain a bunch of YYYY-MM-DD subdirectories
    #
    opendir ($dir_handle, $dir) or die "Can't open $dir: $!";
    while (my $fn = readdir ($dir_handle)) {
        if ($fn =~ /^[.]/) {
            next;
        }
        
        if (-d "$dir/$fn") {
            if ($fn =~ /(\d{4})-(\d{2})-(\d{2})/) {
                #
                # ...\NorthCarolina\YYYY-MM-DD found
                #
                my $fully_qualified_path = "$dir/$fn";
                my $fully_qualified_data_not_available_marker_file = "$fully_qualified_path/.ignore";
                my $fully_qualified_destination_file = "$fully_qualified_path/converted.csv";

                if (-e $fully_qualified_data_not_available_marker_file) {
                    print ("The directory $fn is marked with .ignore\n");
                    next;
                }

                push (@date_dirs, $fully_qualified_path);

                if (-e $fully_qualified_destination_file) {
                    next;
                }

                #
                # Destination not found
                #
                print ("The data file \"$fully_qualified_destination_file\" is missing\n");

                my $source_file = find_nc_source_file ($lookup_hash_ptr, $fn);

                if (!(defined ($source_file))) {
                    next;
                }
                
                if (-e $source_file) {
                    convert_file ($source_file, $fully_qualified_destination_file);
                }
            }
        }
    }

    closedir ($dir_handle);

    return (\@date_dirs);
}

#
#
#
#
sub convert_file {
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
            $record = main::remove_double_quotes_from_column_values ($record);
            $record = main::remove_commas_from_double_quoted_column_values ($record);
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

sub find_nc_source_file {
    my ($lookup_hash_ptr, $date_string) = @_;

    #
    # Figure out how many repositories should be searched
    #
    my $number_of_repositories = 0;
    if (exists ($lookup_hash_ptr->{'northcarolina_source_repository_count'})) {
        $number_of_repositories = $lookup_hash_ptr->{'northcarolina_source_repository_count'};
    }
    elsif (exists ($lookup_hash_ptr->{'northcarolina_source_repository'})) {
        $number_of_repositories = 1;
    }

    #
    # Make a list of repositories. May be zero if nothing was set up at the begin of the
    # main script in the %lookup_hash
    #
    my @repository_list;
    my @path_to_repository_data;
    if ($number_of_repositories == 0) {
        return (undef);
    }
    elsif ($number_of_repositories > 1) {
        for (my $i = 1; $i <= $number_of_repositories; $i++) {
            my $r = $lookup_hash_ptr->{"northcarolina_source_repository_$i"};
            push (@repository_list, "$r");
            my $key = 'northcarolina_source_repository_' . $i . '_path_to_data';
            my $d = $lookup_hash_ptr->{$key};
            push (@path_to_repository_data, "$r/$d");
        }
    }
    else {
        die;  # not set up
        my $r = $lookup_hash_ptr->{"northcarolina_source_repository"};
        push (@repository_list, "$r");
        my $d = $lookup_hash_ptr->{'northcarolina_source_repository_1_path_to_data'};
        push (@path_to_repository_data, "$r/$d");
    }

    my $da;
    my $mo;
    my $yr;
    if ($date_string =~ /(\d{4})-(\d{2})-(\d{2})/) {
        $yr = $1;
        $mo = $2;
        $da = $3;
    }
    else {
        print ("Unexpected date string\n");
        die;
    }

    #
    # Old style file name
    #
    my $name = "nc_zip$mo$da.csv";
    print ("  Searching for $name\n");
    foreach my $path (@path_to_repository_data) {
        print ("    In $path\n");
        my $full_path_and_name = "$path/$name";
        if (-e $full_path_and_name) {
            print ("      Found. Returning $full_path_and_name\n");
            return ($full_path_and_name);
        }
        # else {
        #     print ("    $full_path_and_name not found\n");
        # }
    }

    #
    # New style file name
    #
    my @possibles;
    my $part_name = "nc_zip$yr$mo$da";
    print ("  Searching for $part_name<any time stamp>\n");
    foreach my $path (@path_to_repository_data) {
        print ("    In $path\n");
        my $repository_file_dir_handle;
        opendir ($repository_file_dir_handle, $path) or die "Can't open $path: $!";
        while (my $fn = readdir ($repository_file_dir_handle)) {
            if ($fn =~ /^[.]/) {
                next;
            }

            if ($fn =~ /nc_zip(\d{4})(\d{2})(\d{2})(\d{4})/) {
                my $ftim = $4;
                my $fda = $3;
                my $fmo = $2;
                my $fyr = $1;

                if ($fyr == $yr && $fmo == $mo && $fda == $da) {
                    push (@possibles, "$path/$fn");
                }
            }
        }
        closedir ($repository_file_dir_handle);
    }

    my $c = @possibles;
    if ($c == 0) {
        print ("    Not found\n");
        return (undef);
    }

    if ($c == 1) {
        my $f = shift (@possibles);
        my $full_path_and_name = $f;
        print ("    Found. Returning $full_path_and_name\n");
        return ($full_path_and_name);
    }

    my $t = 0;
    my $selected_t;
    foreach my $f (@possibles) {
        if ($f =~ /nc_zip(\d{4})(\d{2})(\d{2})(\d{4})/) {
            my $ftim = $4;
            my $fda = $3;
            my $fmo = $2;
            my $fyr = $1;

            if ($ftim > $t) {
                $t = $ftim;
                $selected_t = $f;
            }
        }
    }

    my $full_path_and_name = $selected_t;
    print ("    Found. Returning $full_path_and_name\n");
    return ($full_path_and_name);
}

1;
