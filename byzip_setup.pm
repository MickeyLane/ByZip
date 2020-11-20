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
use byzip_setup_newyork;

sub setup {
    my $state = shift;
    my $lookup_hash_ptr = shift;
    my $windows_flag = shift;
    my $begin_sim_dt = shift;

    my %lookup_hash = %$lookup_hash_ptr;

    print ("Setup...\n");
    
    my $output_file_name = $lookup_hash{'byzip_output_file'};

    my $key = $state . '_root';
    my $dir = $lookup_hash{$key};
    $key = 'first_' . $state . '_date_directory';
    my $first_dir_date_string = $lookup_hash{$key};
    my $first_dir = "$dir/$first_dir_date_string";

    my @date_dirs;

    #
    # Go to root dir
    #
    $CWD = $dir;
    # my $cwd = Cwd::cwd();

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
        # return (1, $dir, $date_dirs_ptr, \%lookup_hash);
        @date_dirs = @$date_dirs_ptr;
        goto trim;
    }

    if ($state eq 'pennsylvania') {
        my ($date_dirs_ptr) = byzip_setup_pennsylvania::setup_state ($dir, \%lookup_hash);
        if (defined ($date_dirs_ptr)) {
            @date_dirs = @$date_dirs_ptr;
            goto trim;
        }
    }

    if ($state eq 'northcarolina') {
        my ($date_dirs_ptr) = byzip_setup_northcarolina::setup_state ($dir, \%lookup_hash);
        @date_dirs = @$date_dirs_ptr;
        goto trim;
    }

    if ($state eq 'newyork') {
        byzip_setup_newyork::setup_state ($dir, \%lookup_hash);
    }

    #
    # Examine $dir to make a list in @date_dirs
    #
    opendir (DIR, $dir) or die "Can't open $dir: $!";
    while (my $fn = readdir (DIR)) {
        if ($fn =~ /^[.]/) {
            next;
        }

        my $fully_qualified_file_name = "$dir/$fn";

        if (-d $fully_qualified_file_name) {
            #
            # Directory found
            #
            if ($fn =~ /(\d{4})-(\d{2})-(\d{2})/) {
                # my $date = "$1-$2-$3";
                push (@date_dirs, "$fully_qualified_file_name");
            }
        }
        else {
            #
            # File found
            #
            if ($fn =~ /.gif\z/) {
                next;
            }

            if ($fn =~ /.csv\z/) {
                next;
            }
            
            print ("Don't know what to do with $fully_qualified_file_name\n");
        }
    }

trim:

    #
    # Trim beginning of date directory array
    #
    my $first_date_dir = $date_dirs[0];
    my $i = rindex ($first_date_dir, '/');
    my $date_str = substr ($first_date_dir, $i + 1);
    
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
