#!/usr/bin/perl
package byzip_setup_lookup_hash;
use warnings;
use strict;

#
# SET UP LOCATION & FILE NAME HASH
# ================================
#
#
# This file is kept as a seperate thing so the great number of comments don't
# overwhelm the main script. It's kind of like a .cfg file on Linux
#
# Input:
#    Nothing
#
# Output:
#    A pointer to a configured %lookup_hash
#
sub setup_lookup_hash {
    my $windows_flag = shift;

    my %lookup_hash;

    $lookup_hash{'root'} = 'D:/ByZip';
    $lookup_hash{'byzip_output_file'} = 'byzip-output.csv';
    my $now = DateTime->now;
    $lookup_hash{'todays_date_string'} = sprintf ("%04d %02d %02d", $now->year(), $now->month(), $now->day());
    if (1) {
        #
        # This should only be enabled if the GitHub repositories noted below are on the
        # computer and are being updated daily
        #
        # There is no GitHub repository for Florida. Files are manually downloaded
        # from https://covid19-usflibrary.hub.arcgis.com/search?tags=covidbyzip&type=csv%20collection
        # deposited directly into the appropriatr ByZip/Florida date directory. They are then
        # manually unzipped
        #
        # Maryland repository is https://github.com/wckdouglas/covid19_MD
        #
        $lookup_hash{'maryland_source_repository'} = 'D:/Covid/Maryland/covid19_MD';
        #
        # Pennsylvania repository is https://github.com/ambientpointcorp/covid19-philadelphia
        #
        $lookup_hash{'pensylvania_source_repository'} = 'D:/Covid/Pennsylvania/covid19-philadelphia';
        #
        # New York repository is https://github.com/nychealth/coronavirus-data
        #
        $lookup_hash{'newyork_source_repository'} = 'D:/Covid/NewYork/coronavirus-data';
        #
        # North Carolina uses two. One went obsolete in early October. It's possible the
        # 2nd one could be used by it's self but haven't looked into that yet
        #
        $lookup_hash{'northcarolina_source_repository_count'} = '2';
        #
        # North Carolina repository #1 is https://github.com/mtdukes/nc-covid-by-zip
        #
        $lookup_hash{'northcarolina_source_repository_1'} = 'D:/Covid/NorthCarolina/nc-covid-by-zip (obsolete)';
        $lookup_hash{'northcarolina_source_repository_1_path_to_data'} = 'time_series_data/csv';
        #
        # North Carolina repository #2 is https://github.com/wraldata/nc-covid-data
        #
        $lookup_hash{'northcarolina_source_repository_2'} = 'D:/Covid/NorthCarolina/nc-covid-data';
        $lookup_hash{'northcarolina_source_repository_2_path_to_data'} = 'zip_level_data/time_series_data/csv';
    }

    if ($windows_flag) {
        $lookup_hash{'newyork_root'} = lc 'D:/ByZip/NewYork';
        $lookup_hash{'florida_root'} = lc 'D:/ByZip/Florida';
        $lookup_hash{'maryland_root'} = lc 'D:/ByZip/Maryland';
        $lookup_hash{'northcarolina_root'} = lc 'D:/ByZip/NorthCarolina';
        $lookup_hash{'pennsylvania_root'} = lc 'D:/ByZip/Pennsylvania';
    }
    else {
        $lookup_hash{'newyork_root'} = lc '/home/mickey/ByZip/NewYork';
        $lookup_hash{'florida_root'} = lc '/home/mickey/ByZip/Florida';
        $lookup_hash{'maryland_root'} = lc '/home/mickey/ByZip/Maryland';
        $lookup_hash{'northcarolina_root'} = lc '/home/mickey/ByZip/NorthCarolina';
        $lookup_hash{'pennsylvania_root'} = lc '/home/mickey/ByZip/Pennsylvania';
    }
    
    $lookup_hash{'first_newyork_date_directory'} = '2020-03-31';
    $lookup_hash{'first_florida_date_directory'} = '2020-06-12';
    $lookup_hash{'first_maryland_date_directory'} = '2020-04-12';
    $lookup_hash{'first_northcarolina_date_directory'} = '2020-05-01';
    $lookup_hash{'first_pennsylvania_date_directory'} = '2020-06-17';

    return (\%lookup_hash);
}

1;
