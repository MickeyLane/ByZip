#!/usr/bin/perl
package byzip_setup_maryland;
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
    my $repository = $lookup_hash_ptr->{'maryland_source_repository'};

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
                my $source_file = "$repository/data/$1-$2-$3.tsv";

                if (!(-e $destination_file)) {
                    #
                    # Destination not found
                    #

                    print ("$destination_file is missing\n");

                    if (-e $source_file) {
                        convert_file ($source_file, $destination_file);
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

    my $in_file_handle;
    my $out_file_handle;
    my $record;

    open ($in_file_handle, "<", $in) or die "Can't open $in: $!";

    open ($out_file_handle, ">", $out) or die "Can't create $out: $!";
    print ($out_file_handle "zip,cases\n");

    while ($record = <$in_file_handle>) {
        chomp ($record);

        if ($record =~ /\d{5}\t\d+ Cases/) {
            $record =~ s/ Cases//;
            $record =~ s/\t/,/;
        }
        else {
            print ("Expected \"zip<tab>nn>space>Cases\"\n");
            print ("Got \"$record\"\n");
            exit (1);
        }

        print ($out_file_handle "$record\n");
    }

    close ($in_file_handle);
    close ($out_file_handle);
}

1;
