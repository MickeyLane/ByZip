#!/usr/bin/perl
package byzip_make_random_choices;
use warnings;
use strict;

use LWP::Simple;

#
# This file is part of byzip.pl. See information at the top of that file
#

sub add_random {
    my $hash_ptr = shift;
    my $duration_max = shift;
    my $duration_min = shift;
    my $report_data_collection_messages = shift;
    my $report_adding_case = shift;

    my $local_begin_dt = $hash_ptr->{'begin_dt'};

    #
    # Since random choices are being made, initialize the case to 'not started'
    #
    $hash_ptr->{'sim_state'} = 'not started';

    #
    # If this patient has already been selected as one who is going to die, ignore here
    #
    if (exists ($hash_ptr->{'ending_status'})) {
        if ($hash_ptr->{'ending_status'} eq 'dead') {
            return;
        }
    }
    #
    # This case is cured eventually. Figure out 'eventually'
    #
    my $span = $duration_max - $duration_min + 1;

    #
    # From Google quoting a rather old WHO report:
    #
    # Severity:
    #
    #   Asymptomatic = 50%
    #   Mild = 29%
    #   Severe = 14%
    #   Critical = 5%
    #   Longterm = 2%
    #
    my $severity;
    my $rand_result = int (rand (100) + 1);  # 1..100
    if ($rand_result <= 50) {
        $severity = 'asymptomatic';
    }
    elsif ($rand_result <= 79) {   # 50 + 29
        $severity = 'mild';
    }
    elsif ($rand_result <= 93) {   # 50 + 29 + 14
        $severity = 'severe';
    }
    elsif ($rand_result <= 98) {   # 50 + 29 + 14 + 5
        $severity = 'critical';
    }
    else {
        $severity = 'longterm';
    }

    my $length_of_sickness_for_this_case;
    if ($severity ne '') {
        $length_of_sickness_for_this_case = $duration_min + int (rand ($span) + 1);
    }
    else {
        $length_of_sickness_for_this_case = 80;  # use 80 days
    }

    my $sickness_dur = DateTime::Duration->new (
        days        => $length_of_sickness_for_this_case);

    #
    # Make the end date
    #
    my $end_dt = $local_begin_dt->clone();
    $end_dt->add_duration ($sickness_dur);

    $hash_ptr->{'end_dt'} = $end_dt;
    $hash_ptr->{'ending_status'} = 'cured';
    $hash_ptr->{'severity'} = 'fatal';

    if ($report_data_collection_messages && $report_adding_case) {
        #
        # Debug...
        #
        my $s = $hash_ptr->{'begin_dt'};
        my $e = $hash_ptr->{'end_dt'};

        my $debug_string = sprintf ("%04d-%02d-%02d to %04d-%02d-%02d",
            $s->year(), $s->month(), $s->day(),
            $e->year(), $e->month(), $e->day());

        print ("  Adding case \"$debug_string\"\n");
    }
}

1;
