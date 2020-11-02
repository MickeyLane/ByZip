#!/usr/bin/perl
package byzip_setup;
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

use lib '.';
use byzip_setup_maryland;
use byzip_setup_pennsylvania;
use byzip_setup_northcarolina;

#
# Edit the following as needed. If you are using Linux, ignore '_windows' and vice versa
#
my $fq_florida_root_dir_for_windows = 'D:/ByZip/Florida';
my $fq_florida_root_dir_for_linux = '/home/mickey/ByZip/Florida';
my $fq_newyork_root_dir_for_windows = 'D:/ByZip/NewYork';
my $fq_newyork_root_dir_for_linux = '/home/mickey/ByZip/NewYork';
my $fq_maryland_root_dir_for_windows = 'D:/ByZip/Maryland';
my $fq_maryland_root_dir_for_linux = '/home/mickey/ByZip/Maryland';
my $fq_northcarolina_root_dir_for_windows = 'D:/ByZip/NorthCarolina';
my $fq_northcarolina_root_dir_for_linux = '/home/mickey/ByZip/NorthCarolina';
my $fq_pennsylvania_root_dir_for_windows = 'D:/ByZip/Pennsylvania';
my $fq_pennsylvania_root_dir_for_linux = '/home/mickey/ByZip/Pennsylvania';

my $pp_first_florida_directory = '2020-04-08';
my $pp_first_newyork_directory = '2020-03-31';
my $pp_first_maryland_directory = '2020-04-12';
my $pp_first_northcarolina_directory = '2020-05-01';
my $pp_first_pennsylvania_directory = '2020-06-17';

sub setup {
    my $state = shift;
    my $lookup_hash_ptr = shift;
    my %lookup_hash = %$lookup_hash_ptr;

    print ("Setup...\n");

    my $dir;
    my $first_dir;
    my $first_dir_date_string;
    my $output_file_name = $lookup_hash{'byzip_output_file'};

    #
    # Get current directory and determine platform
    #
    my $windows_flag;
    my $cwd = Cwd::cwd();
    $windows_flag = 0;
    if ($cwd =~ /^[C-Z]:/) {
        $windows_flag = 1;
    }

    if ($windows_flag && $state eq 'newyork') {
        $dir = lc $fq_newyork_root_dir_for_windows;
        $first_dir = "$dir/$pp_first_newyork_directory";
        $first_dir_date_string = $pp_first_newyork_directory;
    }
    elsif ($windows_flag == 0 && $state eq 'newyork') {
        $dir = lc $fq_newyork_root_dir_for_linux;
        $first_dir = "$dir/$pp_first_newyork_directory";
        $first_dir_date_string = $pp_first_newyork_directory;
    }
    elsif ($windows_flag && $state eq 'florida') {
        $dir = lc $fq_florida_root_dir_for_windows;
        $first_dir = "$dir/$pp_first_florida_directory";
        $first_dir_date_string = $pp_first_florida_directory;
    }
    elsif ($windows_flag == 0 && $state eq 'florida') {
        $dir = lc $fq_florida_root_dir_for_linux;
        $first_dir = "$dir/$pp_first_florida_directory";
        $first_dir_date_string = $pp_first_florida_directory;
    }
    elsif ($windows_flag && $state eq 'maryland') {
        $dir = lc $fq_maryland_root_dir_for_windows;
        $first_dir = "$dir/$pp_first_maryland_directory";
        $first_dir_date_string = $pp_first_maryland_directory;
    }
    elsif ($windows_flag == 0 && $state eq 'maryland') {
        $dir = lc $fq_maryland_root_dir_for_linux;
        $first_dir = "$dir/$pp_first_maryland_directory";
        $first_dir_date_string = $pp_first_maryland_directory;
    }
    elsif ($windows_flag && $state eq 'northcarolina') {
        $dir = lc $fq_northcarolina_root_dir_for_windows;
        $first_dir = "$dir/$pp_first_northcarolina_directory";
        $first_dir_date_string = $pp_first_northcarolina_directory;
    }
    elsif ($windows_flag == 0 && $state eq 'northcarolina') {
        $dir = lc $fq_northcarolina_root_dir_for_linux;
        $first_dir = "$dir/$pp_first_northcarolina_directory";
        $first_dir_date_string = $pp_first_northcarolina_directory;
    }
    elsif ($windows_flag && $state eq 'pennsylvania') {
        $dir = lc $fq_pennsylvania_root_dir_for_windows;
        $first_dir = "$dir/$pp_first_pennsylvania_directory";
        $first_dir_date_string = $pp_first_pennsylvania_directory;
    }
    elsif ($windows_flag == 0 && $state eq 'pennsylvania') {
        $dir = lc $fq_pennsylvania_root_dir_for_linux;
        $first_dir = "$dir/$pp_first_pennsylvania_directory";
        $first_dir_date_string = $pp_first_pennsylvania_directory;
    }
    else {
        print ("Can't figure out base \$dir\n");
        print ("  \$windows_flag = $windows_flag\n");
        print ("  \$state = $state\n");
        exit (1);
    }

    #
    # Go to root dir
    #
    $CWD = $dir;
    $cwd = Cwd::cwd();

    if (!(-e $first_dir)) {
        print ("Creating first directory...\n");
        # local $dir;
        mkdir ($first_dir_date_string) or die "Can not create $first_dir_date_string: $!";
    }

    if (!(-e $first_dir)) {
        print ("Did not create first directory\n");
        exit (1);
    }

    #
    # Make missing date directories
    #
    my $not_done = 1;
    while ($not_done) {
        $not_done = make_new_dirs ($dir);
    }

    #
    # Do setups for various states if this is a development machine with the
    # necessary repositories, etc
    #
    if ($state eq 'maryland' && exists ($lookup_hash{'maryland_source_repository'})) {
        my ($date_dirs_ptr) = byzip_setup_maryland::setup_state ($dir, \%lookup_hash);
        return (1, $dir, $date_dirs_ptr, \%lookup_hash);
    }

    if ($state eq 'pennsylvania' && exists ($lookup_hash{'pensylvania_source_repository'})) {
        my ($date_dirs_ptr) = byzip_setup_pennsylvania::setup_state ($dir, \%lookup_hash);
        return (1, $dir, $date_dirs_ptr, \%lookup_hash);
    }

    if ($state eq 'northcarolina') {
        my ($date_dirs_ptr) = byzip_setup_northcarolina::setup_state ($dir, \%lookup_hash);
        return (1, $dir, $date_dirs_ptr, \%lookup_hash);
    }

    #
    # Examine $dir
    #
    my @date_dirs;

    opendir (DIR, $dir) or die "Can't open $dir: $!";
    while (my $fn = readdir (DIR)) {
        if ($fn =~ /^[.]/) {
            next;
        }

        my $fq_fn = "$dir/$fn";

        if (-d $fq_fn) {
            #
            # Directory found
            #
            if ($fn =~ /(\d{4})-(\d{2})-(\d{2})/) {
                # my $date = "$1-$2-$3";
                push (@date_dirs, "$fq_fn");
            }
        }
        else {
            #
            # File found
            #
            my @suffixlist = qw (.csv .tsv .gz);
            my ($name, $path, $suffix) = fileparse ($fq_fn, @suffixlist);

            if ($suffix eq '') {
                next;
            }
            elsif ($suffix eq '.gz') {
                die;
            }
            elsif ($suffix eq '.tsv') {
                die;
            }
            elsif ($suffix eq '.csv') {
                if ("$name.csv" eq $output_file_name) {
                    next;
                }

                if ($fn =~ /nc_zip(\d{2})(\d{2})/) {
                    my $fq_new_dir = "$dir/2020-$1-$2";
                    my $fq_new_file = "$fq_new_dir/converted.csv";

                    byzip_cleanups::cleanup_northcarolina_csv_files ($fq_fn, $fq_new_file);

                }
                else {
                    print ("Don't know what to do with $fq_fn\n");
                    exit (1);
                }
            }
            else {
                print ("Don't know what to do with $fq_fn\n");
            }
        }
    }

    return (1, $dir, \@date_dirs, \%lookup_hash);
}

###################################################################################
#
# This could be improved. See relative method
#
sub make_new_dirs {
    my $dir = shift;

    my $dur = DateTime::Duration->new (days => 1);
    my $now = DateTime->now;

    my @all_date_dirs;
    my $did_something_flag = 0;

    opendir (DIR, $dir) or die "Get_db_files() can't open $dir: $!";
    while (my $ff = readdir (DIR)) {
        #
        # This is used to rename a bunch of YYYY MM DD directories to YYYY-MM-DD
        #
        # if ($ff =~ /^(\d{4}) (\d{2}) (\d{2})/) {
        #     my $oldff = "$dir/$ff";
        #     my $newff = "$dir/$1-$2-$3";
        #     rename ($oldff, $newff) or die "Can't rename $oldff: $!";
        # }

        if ($ff =~ /^(\d{4})-(\d{2})-(\d{2})/) {
            push (@all_date_dirs, "$ff");
    
            my $current_dt = DateTime->new(
                year       => $1,
                month      => $2,
                day        => $3
            );

            my $next_dt = $current_dt->add_duration ($dur);
            if ($next_dt > $now) {
                next;
            }

            my $next_dir_string = sprintf ("%04d-%02d-%02d",
                $next_dt->year(),
                $next_dt->month(),
                $next_dt->day());

            if (-e $next_dir_string) {
                next;
            }

            print ("Creating missing date directory $next_dir_string\n");

            mkdir ($next_dir_string) or die "Can't make $next_dir_string: $!";

            $did_something_flag = 1;
        }
    }

    close (DIR);

    return ($did_something_flag);
}

1;
