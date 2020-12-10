#!/usr/bin/perl
package byzip_c;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use lib '.';
use byzip_int_chk;

#
# Input:
#
#   @cases_list:
#
#       The list of cases to be processed
#
#   %cases_by_date:
#
#       A hash in the form "YYYY-MM-DD => NNN" where NNN is the number of new cases on the given date
#
sub process {
    my $cases_list_ptr = shift;
    my $new_cases_by_date_ptr = shift;
    my $last_serial = shift;
    my $print_stuff = shift;
    
    my @cases_list = @$cases_list_ptr;
    my $case_count = @cases_list;
    my %new_cases_by_date = %$new_cases_by_date_ptr;

    #
    # Set up things needed below
    #
    my $running_total_of_dead = 0;
    my $running_total_of_cured = 0;
    my $currently_sick = 0;
    my $untested_positive_currently_sick = 0;
    my $currently_infectious = 0;
    my @output_csv;
    my $non_sim_columns;
    my $sim_columns;
    my $output_csv_has_header = 0;
    my $one_day_duration_dt = DateTime::Duration->new (days => 1);

    #
    # Get the earliest and latest dates in the list of cases to
    # establish sim run time
    #
    my $temp_hash_ptr = $cases_list[0];
    my $first_simulation_dt = $temp_hash_ptr->{'begin_dt'};

    $temp_hash_ptr = $cases_list[$case_count - 1];
    my $last_simulation_dt = $temp_hash_ptr->{'begin_dt'};

    #
    # Set up the simulation
    #
    my $current_sim_dt = $first_simulation_dt->clone();
    my $processing_day_number = 1;
    my $do_startup_safty_check = 1;
    my $finished_processing_all_the_days_flag = 0;

    #
    # Sim
    #
    while (!$finished_processing_all_the_days_flag) {
        #
        # Debug...
        #
        if ($do_startup_safty_check) {
            byzip_int_chk::integrety_check (\@cases_list, $case_count, 1, 0, __FILE__, __LINE__);
            $do_startup_safty_check = 0;
        }

        my $dir_string = main::make_printable_date_string ($current_sim_dt);
        if ($print_stuff) {
            print ("\n$dir_string...\n");
        }

        my $new_cases_for_current_sim_date = 0;
        if (exists ($new_cases_by_date{$dir_string})) {
            $new_cases_for_current_sim_date = $new_cases_by_date{$dir_string};
            # print ("New cases for $dir_string = $new_cases_for_current_sim_date\n");
        }

        my @to_be_processed_cases_list;
        my $current_sim_epoch = $current_sim_dt->epoch();
        my $top_case_ptr;
        my $string_for_debug;

        my $a_case_was_processed = 0;
        my $finished_processing_this_day = 0;
        while (!$finished_processing_this_day) {
            #
            # Get the next case
            #
            $top_case_ptr = shift (@cases_list);
            if (!(defined ($top_case_ptr))) {
                #
                # Hit the end of the list
                #
                $finished_processing_this_day = 1;
                goto end_of_cases_for_this_sim_date;
            }

            my $top_case_begin_dt = $top_case_ptr->{'begin_dt'} or die "Begin date is undefined";
            my $this_case_begin_epoch = $top_case_begin_dt->epoch();

            my $top_case_end_dt = $top_case_ptr->{'end_dt'} or die "End date is undefined";
            my $this_case_end_epoch = $top_case_end_dt->epoch();

            my $serial = $top_case_ptr->{'serial'};
            my $case_state = $top_case_ptr->{'sim_state'};

            if ($print_stuff) {
                my $b = main::make_printable_date_string ($top_case_begin_dt);
                my $e = main::make_printable_date_string ($top_case_end_dt);
                print ("  Processing serial $serial ($b to $e) in state \"$case_state\"\n");
            }

            if ($case_state eq 'cured') {
                print ("  Attempt to process a cured case. \$serial = $serial\n");
                die;
            }

            if ($this_case_end_epoch < $current_sim_epoch) {
                #
                # Error
                # -----
                #
                # Case ended before the current sim date
                # Should not be in the list
                #
                print ("Found a case that ended before the current sim date\n");
                byzip_debug::report_case (
                    \@to_be_processed_cases_list,
                    $top_case_ptr,
                    \@cases_list);

                die;
            }

            if ($this_case_begin_epoch > $current_sim_epoch) {
                #
                # Not yet
                # -------
                #
                # This case can not be processed yet
                # Put it in the new list. Use the default output line
                #
                add_to_new_cases_list (\@to_be_processed_cases_list, $top_case_ptr) or die;

                $string_for_debug = 'can not process yet';

                if ($a_case_was_processed) {
                    $finished_processing_this_day = 1;
                }

                undef ($top_case_ptr);
                goto end_of_cases_for_this_sim_date;
            }

            if ($this_case_begin_epoch == $current_sim_epoch) {
                #
                # Begin
                # -----
                #
                # Put it in the new list
                #
                add_to_new_cases_list (\@to_be_processed_cases_list, $top_case_ptr) or die;

                #
                # Determine type of new case
                #
                my $this_is_an_untested_positive_case = 0;
                my $this_is_an_infectious_case = 0;

                if (exists ($top_case_ptr->{'untested_positive'})) {
                    $this_is_an_untested_positive_case = 1;
                }

                if (exists ($top_case_ptr->{'infectious'})) {
                    $this_is_an_infectious_case = 1;
                }

                #
                # Process types of new cases
                #
                if ($this_is_an_untested_positive_case) {
                    $untested_positive_currently_sick++;
                    # print ("+++ \$untested_positive_currently_sick = $untested_positive_currently_sick\n");

                    $top_case_ptr->{'sim_state'} = 'untested positive sick';

                }
                elsif ($this_is_an_infectious_case) {
                    $currently_infectious += 1;
                    $top_case_ptr->{'sim_state'} = 'infectious sick';
                }
                else {
                    $currently_sick++;
                    $top_case_ptr->{'sim_state'} = 'sick';
                }

                $string_for_debug = 'new';

                $a_case_was_processed = 1;
                undef ($top_case_ptr);
                goto end_of_cases_for_this_sim_date;

            }

            if ($this_case_begin_epoch < $current_sim_epoch && $this_case_end_epoch > $current_sim_epoch) {
                #
                # In progress
                # -----------
                #
                # Put it in the new list. Use the default output line
                #
                # print ("  In progress...\n");

                my $state = $top_case_ptr->{'sim_state'};
                if ($state ne 'sick' && $state ne 'untested positive sick') {
                    print ("\n$dir_string...\n");
                    print ("  \$processing_day_number = $processing_day_number\n");

                    print ("  Found an in-progress case not marked \"sick.\" Marked \"$state\"\n");

                    byzip_debug::report_case (
                        \@to_be_processed_cases_list,
                        $top_case_ptr,
                        \@cases_list);

                    my $temp_dt = DateTime->from_epoch (epoch => $this_case_begin_epoch);
                    my $temp_string = main::make_printable_date_string ($temp_dt);
                    print ("  \$this_case_begin_epoch = $temp_string\n");

                    $temp_dt = DateTime->from_epoch (epoch => $current_sim_epoch);
                    $temp_string = main::make_printable_date_string ($temp_dt);
                    print ("  \$current_sim_epoch = $temp_string\n");

                    $temp_dt = DateTime->from_epoch (epoch => $this_case_end_epoch);
                    $temp_string = main::make_printable_date_string ($temp_dt);
                    print ("  \$this_case_end_epoch = $temp_string\n");
                    die;
                }

                add_to_new_cases_list (\@to_be_processed_cases_list, $top_case_ptr) or die;

                $string_for_debug = 'ongoing';

                $a_case_was_processed = 1;
                undef ($top_case_ptr);
                goto end_of_cases_for_this_sim_date;
            }

            if ($this_case_end_epoch == $current_sim_epoch) {
                #
                # End a case
                # ----------
                #
                # Do NOT put it in the new list
                #
                # Determine type of ending case
                #
                my $this_is_an_untested_positive_case = 0;
                my $this_is_an_infectious_case = 0;

                if (exists ($top_case_ptr->{'untested_positive'})) {
                    $this_is_an_untested_positive_case = 1;
                }

                if (exists ($top_case_ptr->{'infectious'})) {
                    $this_is_an_infectious_case = 1;
                }

                #
                # Process types of ending cases
                #
                if ($this_is_an_untested_positive_case) {
                    $untested_positive_currently_sick--;

                    #
                    # Debug...
                    #
                    if ($untested_positive_currently_sick < 0) {
                        print ("Attempt to move an untested positive case from sick status to cured status\n");
                        print ("Untested positive count is now below zero\n");
                        exit (1);
                    }
                }
                elsif ($this_is_an_untested_positive_case) {
                    $currently_infectious -= 1;

                    #
                    # Debug...
                    #
                    if ($currently_infectious < 0) {
                        print ("Removed an infected case from the count\n");
                        print ("Count is now below zero\n");
                        exit (1);
                    }
                }
                else {
                    $currently_sick--;

                    #
                    # Get the case disposition
                    #
                    my $end_status = $top_case_ptr->{'ending_status'};
                    if ($end_status eq 'dead') {
                        $running_total_of_dead++;
                        # $top_case_ptr->{'sim_state'} = 'dead';
                    }
                    elsif ($end_status eq 'cured') {
                        $running_total_of_cured++;
                        # $top_case_ptr->{'sim_state'} = 'cured';
                    }
                }

                $string_for_debug = 'ending';

                $a_case_was_processed = 1;
                undef ($top_case_ptr);
                goto end_of_cases_for_this_sim_date;
            }

            print ("No clue how this happened\n");
            print ("  $dir_string...\n");
            my $temp_dt = DateTime->from_epoch (epoch => $this_case_begin_epoch);
            my $temp_string = main::make_printable_date_string ($temp_dt);
            print ("  \$this_case_begin_epoch = $temp_string\n");

            $temp_dt = DateTime->from_epoch (epoch => $current_sim_epoch);
            $temp_string = main::make_printable_date_string ($temp_dt);
            print ("  \$current_sim_epoch = $temp_string\n");

            $temp_dt = DateTime->from_epoch (epoch => $this_case_end_epoch);
            $temp_string = main::make_printable_date_string ($temp_dt);
            print ("  \$this_case_end_epoch = $temp_string\n");

            # my $cases_list_1_ptr = byzip_debug::make_case_list (\@to_be_processed_cases_list);
            # my $cases_list_2_ptr = byzip_debug::make_case_list (\@cases_list);

            byzip_debug::report_case (
                \@to_be_processed_cases_list,
                $top_case_ptr,
                \@cases_list);
            die;

end_of_cases_for_this_sim_date:

            $processing_day_number++;

            if ($print_stuff) {
                print ("  Result: $string_for_debug\n");
            }
        }
        
        #
        # Processing for the day is complete
        #
        my $new_cnt = @to_be_processed_cases_list;
        my $old_cnt = @cases_list;
        if ($print_stuff) {
            print ("  New cases list has $new_cnt cases, old list has $old_cnt\n");
        }

        if (defined ($top_case_ptr)) {
            print ("\$top_case_ptr is defined when it should not be\n");
            die;
        }

        if ($old_cnt > 0) {
            add_to_new_cases_list (\@to_be_processed_cases_list, \@cases_list) or die;
        }

        #
        # Move the new cases list over to the cases list
        #
        @cases_list = @to_be_processed_cases_list;
        undef (@to_be_processed_cases_list);

        my $output_line = sprintf ("%s,%d,%d,%d,%d,%d,%d",
            $dir_string,
            $new_cases_for_current_sim_date,
            $running_total_of_cured,
            $currently_infectious,
            $currently_sick,
            $untested_positive_currently_sick,
            $running_total_of_dead);

        if (!$output_csv_has_header) {
            push (@output_csv, "Date,New,Cured,Infectious,Sick,UntestedSick,Dead");
            $non_sim_columns = 2;
            $sim_columns = 5;
            $output_csv_has_header = 1;
        }

        push (@output_csv, "$output_line");

        my $d = DateTime->compare ($current_sim_dt, $last_simulation_dt);
        if ($d == 0) {
            $finished_processing_all_the_days_flag = 1;
        }
        else {
            $current_sim_dt->add_duration ($one_day_duration_dt);
        }
    }

    return (\@output_csv, $non_sim_columns, $sim_columns);
}

sub add_to_new_cases_list {
    my $new_case_list_input = shift;
    my $case_input = shift;

    my $on_success_print_comments = 0;

    my @list;
    my %case;
    my @case_list;
    my $add_single_case_flag = 0;
    my $add_list_of_cases_flag = 0;
    my @comment_list;

    push (@comment_list, "In add_to_new_cases_list...");

    #
    # Figure out 1st argument
    #
    my $type = ref ($new_case_list_input);
    push (@comment_list, "  1st \$type = $type");

    if ($type eq 'ARRAY') {
        @list = @$new_case_list_input;
    }
    else {
        die "Bad list input";
    }

    #
    # Figure out 2nd argument
    #
    $type = ref ($case_input);
    push (@comment_list, "  2nd \$type = $type");
    
    if ($type eq 'HASH') {
        %case = %$case_input;
        $add_single_case_flag = 1;
    }
    elsif ($type eq 'ARRAY') {
        @case_list = @$case_input;
        $add_list_of_cases_flag = 1;
    }
    else {
        die "Bad case input";
    }

    my $case_list_len = @list;
    push (@comment_list, "  \$case_list_len = $case_list_len");

    if ($add_single_case_flag) {
        if ($case_list_len == 0) {
            push (@$new_case_list_input, $case_input);
            goto success_exit;
        }

        my $last_hash_ptr = $list[$case_list_len - 1];
        my $last_list_serial = $last_hash_ptr->{'serial'};

        my $case_serial = $case{'serial'};

        push (@comment_list, "  \$last_list_serial = $last_list_serial");
        push (@comment_list, "  \$case_serial = $case_serial");

        if ($case_serial < $last_list_serial) {
            push (@comment_list, "  Out of sequence add attampt");
            goto error_exit;
        }

        push (@$new_case_list_input, $case_input);
        goto success_exit;
    }
    elsif ($add_list_of_cases_flag) {
        if ($case_list_len == 0) {
            push (@$new_case_list_input, @case_list);
            goto success_exit;
        }

        my $last_hash_ptr = $list[$case_list_len - 1];
        my $last_list_serial = $last_hash_ptr->{'serial'};

        my $first_list_hash_ptr = $case_list[0];
        my $first_list_serial = $first_list_hash_ptr->{'serial'};

        if ($first_list_serial < $last_list_serial) {
            push (@comment_list, "  Out of sequence list add attampt");
            goto error_exit;
        }

        push (@$new_case_list_input, @case_list);
        goto success_exit;
    }

    die "Not supposed to reach this point";

success_exit:
    if ($on_success_print_comments) {
        foreach my $c (@comment_list) {
            print ("  $c\n");
        }
    }

    return (1);


error_exit:
    foreach my $c (@comment_list) {
        print ("  $c\n");
    }

    return (0);
}

########################################################################################
#
# Input:
#
#   $cases_by_date is a list of strings in the following format:
#
#      YYYY-MM-DD N
#
#      N is the number of new cases on the date indicated
#
# sub search_new_cases {
#     my ($cases_by_date_ptr, $current_sim_dt) = @_;

#     my $new_cases = 0;

#     foreach my $line (@$cases_by_date_ptr) {
#         if ($line =~ /(\d{4})-(\d{2})-(\d{2})/) {
#             my $line_dt = DateTime->new(
#                     year       => $1,
#                     month      => $2,
#                     day        => $3);

#             my $count_str = substr ($line, 11);

#             if ($line_dt == $current_sim_dt) {
#                 return $count_str;
#             }
#         }
#         else {
#             print ("In search_new_cases(), expected YYYY-MM-DD N\n");
#             print ("Got $line\n");
#             die;
#         }
#     }

#     return (0);
# }

# sub search_new_cases_2 {
#     my ($cases_by_date_ptr, $sim_date_str) = @_;

#     my $new_cases = 0;

#     foreach my $line (@$cases_by_date_ptr) {
#         my $line_date_str = substr ($line, 0, 10);
#         my $count_str = substr ($line, 11);

#         if ($line_date_str eq $sim_date_str) {
#             return $count_str;
#         }
#     }

#     return (0);
# }

1;
