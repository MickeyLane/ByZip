#!/usr/bin/perl
package byzip_delete_cases;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use lib '.';
use byzip_int_chk;

#
# Note: This function is not called very often and it's never called during
# simulation so speed is not important
#
sub delete_cases_from_list {
    my $cases_list_ptr = shift;
    my $cases_to_delete_count = shift;
    my $zip = shift;
    my $case_serial_number = shift;
    my $report_data_collection_messages = shift;

    my $print_debug_strings = 0;

    if ($print_debug_strings) {
        print ("\nDeleting cases from zip $zip\n");
    }

    my @cases_to_keep_1;
    my @cases_list = @$cases_list_ptr;

    my $case_count;

    my $j = $cases_to_delete_count;
    while ($j) {
        $case_count = @cases_list;
        if ($case_count == 0) {
            die "  While attempting to delete cases due to a negative new case count, ran out of cases";
        }

        #
        # Get the last case that was added to the list
        #
        my $hash_ptr = pop (@cases_list);
        my $from_zip = $hash_ptr->{'from_zip'};

        if ($zip != $from_zip) {
            #
            # If the case was NOT from this zip code, keep it. Don't count it
            #
            push (@cases_to_keep_1, $hash_ptr);
        }
        else {
            #
            # It was from the zip so trash it. Count it
            #
            my $serial = $hash_ptr->{'serial'};
            if ($report_data_collection_messages) {
                print ("  Deleting case with serial = $serial\n");
            }
            $j--;
        }
    }

    $case_count = @cases_list;
    my $result = byzip_int_chk::integrety_check (\@cases_list, $case_count, 0, $print_debug_strings, __FILE__, __LINE__);
    if (!$result) {
        die;
    }

    #
    # Get the serial number of the last case in the list and
    # reset the serial number counter
    #
    my $last_serial = get_last_serial (\@cases_list);
    if ($print_debug_strings) {
        print ("  Last serial in the just trimmed list is $last_serial\n");
    }

    $case_serial_number = $last_serial + 1;

    #
    # See if two lists need to be joined
    #
    $case_count = @cases_to_keep_1;
    if ($case_count == 0) {
        #
        # There are no cases to re-add to the list. We're done here
        #
        if ($print_debug_strings) {
            print ("  Did not need to re-add cases\n");
        }
        return (\@cases_list, $case_serial_number);
    }

    $result = byzip_int_chk::integrety_check (\@cases_to_keep_1, $case_count, 0, $print_debug_strings, __FILE__, __LINE__);
    if (!$result) {
        my @new_cases_list = sort case_sort_routine (@cases_to_keep_1);
        @cases_to_keep_1 = @new_cases_list;
    }

    #
    # Get the epoch value of the start date from the last case in the list
    #
    my $last_epoch_from_existing_list = get_last_begin_date_epoch (\@cases_list);
    my $first_epoch_from_list_to_add = get_first_begin_date_epoch (\@cases_to_keep_1);

    if ($last_epoch_from_existing_list <= $first_epoch_from_list_to_add) {
        foreach my $case_ptr (@cases_to_keep_1) {
            $case_ptr->{'serial'} = $case_serial_number++;
            push (@cases_list, $case_ptr);
        }

        $case_count = @cases_list;
        my $result = byzip_int_chk::integrety_check (\@cases_list, $case_count, 0, $print_debug_strings, __FILE__, __LINE__);
        if (!$result) {
            my $temp_dt = DateTime->from_epoch (epoch => $last_epoch_from_existing_list);
            my $temp_string = main::make_printable_date_string ($temp_dt);
            print ("  Start date in last element of existing list is $temp_string\n");

            $temp_dt = DateTime->from_epoch (epoch => $first_epoch_from_list_to_add);
            $temp_string = main::make_printable_date_string ($temp_dt);
            print ("  Start date in first element of list to be added is $temp_string\n");

            $case_count = @cases_to_keep_1;
            print ("  List to be added has $case_count elements\n");
            die;
        }

        if ($print_debug_strings) {
            print ("  Added cases\n");
        }

        return (\@cases_list, $case_serial_number);
    }

    die;

}

sub get_last_serial {
    my $cases_list_ptr = shift;

    my @cases_list = @$cases_list_ptr;

    my $case_count = @cases_list;
    my $last_serial = $cases_list[$case_count - 1]->{'serial'};

    return ($last_serial);
}

sub get_last_begin_date_epoch {
    my $cases_list_ptr = shift;

    my @cases_list = @$cases_list_ptr;

    my $case_count = @cases_list;
    my $begin_dt = $cases_list[$case_count - 1]->{'begin_dt'};
    my $epoch_value = $begin_dt->epoch();

    return ($epoch_value);
}

sub get_first_begin_date_epoch {
    my $cases_list_ptr = shift;

    my @cases_list = @$cases_list_ptr;

    my $begin_dt = $cases_list[0]->{'begin_dt'};
    my $epoch_value = $begin_dt->epoch();

    return ($epoch_value);
}

###################################################################################
#
#
sub case_sort_routine {

    my $a_dt = $a->{'begin_dt'};
    my $b_dt = $b->{'begin_dt'};
    
    return (DateTime->compare ($a_dt, $b_dt));
}

1;
