#!/usr/bin/perl
package byzip_debug;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

my $print_stuff = $main::pp_report_sim_messages;

sub make_case_list {
    my $input = shift;

    my @cases_list;
    my @debug_cases_list;

    my $type = ref ($input);
    if ($type eq 'ARRAY') {
        @cases_list = @$input;
    }
    elsif ($type eq 'SCALAR') {
        my %temp = %$input;
        push (@cases_list, %temp);
    }

    foreach my $tc (@cases_list) {
        my $begin_dt = $tc->{'begin_dt'};
        my $end_dt = $tc->{'end_dt'};
        my $s = $tc->{'serial'};

        my $debug_string = sprintf ("serial: %03d  begin date: %04d-%02d-%02d",
            $s,
            $begin_dt->year(),
            $begin_dt->month(),
            $begin_dt->day());

        push (@debug_cases_list, $debug_string);
        # print ("$s is $debug_string\n");
    }

    return (\@debug_cases_list);
}

sub report_case {
    my ($to_be_processed_cases_list_ptr, $current_case, $cases_list) = @_;

    # my $debug_cases_list_ptr = shift;
    # my $case_index = shift;
    # my $current_sim_dt = shift;
    # my $top_case_begin_dt = shift;
    # my $top_case_end_dt = shift;
    # my $begin_cmp_result = shift;
    # my $end_cmp_result = shift;

    my @debug_cases_list;
    my $line;
    my $first_line_to_print;
    my $dt;

    # my @list;

    my $len = @$to_be_processed_cases_list_ptr;
    if ($len) {
        $first_line_to_print = $len - 10;
        if ($first_line_to_print < 0) {
            $first_line_to_print = 0;
        }

        for (my $i = $first_line_to_print; $i < $len; $i++) {
            my $hash = shift (@$to_be_processed_cases_list_ptr);
            # push (@list, $hash);
            $line = sprintf ("  %s to %s is serial %03d",
                main::make_printable_date_string ($hash->{'begin_dt'}),
                main::make_printable_date_string ($hash->{'end_dt'}),
                $hash->{'serial'});
            push (@debug_cases_list, $line);
        }
    }

    # push (@list, $current_case);
    $line = sprintf ("  %s to %s is serial %03d **",
        main::make_printable_date_string ($current_case->{'begin_dt'}),
        main::make_printable_date_string ($current_case->{'end_dt'}),
        $current_case->{'serial'});
    push (@debug_cases_list, $line);

    $len = @$cases_list;
    if ($len) {
        $first_line_to_print = 0;
    
        my $last_line_to_print = 10;
        if ($last_line_to_print > $len) {
            $last_line_to_print = $len;
        }

        for (my $i = $first_line_to_print; $i <= $last_line_to_print; $i++) {
            my $hash = shift (@$cases_list);
            # push (@list, $hash);
            $line = sprintf ("  %s to %s is serial %03d",
                main::make_printable_date_string ($hash->{'begin_dt'}),
                main::make_printable_date_string ($hash->{'end_dt'}),
                $hash->{'serial'});
            push (@debug_cases_list, $line);
        }
    }

    foreach my $p (@debug_cases_list) {
        print ("$p\n");
    }

    # my $begin_dt = $current_case->{'begin_dt'};
    # my $end_dt = $current_case->{'end_dt'};

    # print ("  Sim is doing " . main::make_printable_date_string ($begin_dt) . "\n");

    # my $end_debug_string = sprintf ("%04d-%02d-%02d",
    #     $top_case_end_dt->year(), $top_case_end_dt->month(), $top_case_end_dt->day());
    # # print ("  \$top_case_end_dt is $debug_string\n");

    # my $begin_debug_string = sprintf ("%04d-%02d-%02d",
    #     $top_case_begin_dt->year(), $top_case_begin_dt->month(), $top_case_begin_dt->day());
    # print ("  Case is sick: $begin_debug_string to $end_debug_string\n");

    # print ("  \$begin_cmp_result = $begin_cmp_result\n");
    # print ("  \$end_cmp_result = $end_cmp_result\n");
    # exit (1);

                # my $cases_list_1_ptr = byzip_debug::make_case_list (\@cases_list);
                # my $cases_list = byzip_debug::make_case_list ($top_case_ptr);
                # my $cases_list_3_ptr = byzip_debug::make_case_list (\@to_be_processed_cases_list);

                # my @debug_case_list = @$cases_list_1_ptr;
                # push (@debug_case_list, @$cases_list);
                # push (@debug_case_list, @$cases_list_3_ptr);

                # foreach my $dcl (@debug_case_list) {
                #     print ("$dcl\n");
                # }

}

1;
