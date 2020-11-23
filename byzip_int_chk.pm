#!/usr/bin/perl
package byzip_int_chk;
use warnings;
use strict;

#
# Startup safty check
#
sub integrety_check {
    my $cases_list_ptr = shift;
    my $case_count = shift;
    my $test_end_date = shift;
    my $print_debug_strings = shift;
    my $file = shift;
    my $line = shift;

    my @cases_list = @$cases_list_ptr;

    my $last_begin_dt;
    my $last_serial;
    for (my $i = 0; $i < $case_count; $i++) {
        if (!(defined ($cases_list[$i]))) {
            print ("  An element (hash ptr) in the cases list is undefined\n");
            print ("  Startup check FAIL from $file line $line\n");
            return (0);
        }

        my $serial = $cases_list[$i]{'serial'};
        my $begin_dt = $cases_list[$i]{'begin_dt'};

        if (!(defined ($begin_dt))) {
            print ("  Begin date is undefined\n");
            print ("  Startup check FAIL. Called from $file line $line\n");
            return (0);
        }
        
        if ($test_end_date) {
            my $end_dt = $cases_list[$i]{'end_dt'};
            if (!(defined ($end_dt))) {
                print ("  End date is undefined\n");
                print ("  Startup check FAIL. Called from $file line $line\n");
                return (0);
            }
        }

        if ($i == 0) {
            $last_begin_dt = $begin_dt;
            $last_serial = $serial;
        }

        if ($begin_dt < $last_begin_dt) {
            if ($print_debug_strings) {
                print ("  Begin occurs before previous begin\n");
                print ("    \$i = $i\n");
                print ("    \$case_count = $case_count\n");
                print ("    \$serial = $serial\n");
                print ("  Startup check FAIL. Called from $file line $line\n");
            }
            return (0);
        }
        else {
            $last_begin_dt = $begin_dt;
        }

        if ($serial < $last_serial) {
            if ($print_debug_strings) {
                print ("  Serial numbers are out of sequence\n");

                print ("    \$i = $i\n");
                print ("    \$case_count = $case_count\n");
                print ("    \$serial = $serial\n");
                print ("  Startup check FAIL. Called from $file line $line\n");
            }
            return (0);
        }
        else {
            $last_begin_dt = $begin_dt;
        }
    }

    if ($print_debug_strings) {
        print ("  Startup check PASS. Called from $file line $line\n");
    }

    return (1);
}

1;
