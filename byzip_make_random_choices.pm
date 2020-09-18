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
    my $enable_use_of_owid_mortality_data = shift;
    my $mortality_table_ptr = shift;
    my $fixed_mortality = shift;
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
    # Determine if this patient is going to die
    #
    if (predict_case_is_fatal (
            $enable_use_of_owid_mortality_data,
            $mortality_table_ptr, $fixed_mortality, $local_begin_dt)) {
        #
        # Case is fatal. Assume 5-10 days sick
        #
        my $span = 6;
        my $length_of_sickness_for_this_case = 5 + int (rand ($span) + 1);

        my $sickness_dur = DateTime::Duration->new (
            days        => $length_of_sickness_for_this_case);

        my $end_dt = $local_begin_dt->clone();
        $end_dt->add_duration ($sickness_dur);

        $hash_ptr->{'ending_status'} = 'dead';
        $hash_ptr->{'end_dt'} = $end_dt;
        $hash_ptr->{'severity'} = 'fatal';

        goto end_of_random_assignments;
    }

    #
    # From Google quoting a rather old WHO report:
    #
    # Severity:
    #
    #   Asymptomatic = 50%
    #   Mild = 30%
    #   Severe = 15%
    #   Critical = 5%
    #
    #
    my $severity;
    my $rand_result = int (rand (100) + 1);  # 1..100
    if ($rand_result <= 50) {
        $severity = 'asymptomatic';
    }
    elsif ($rand_result <= 80) {
        $severity = 'mild';
    }
    elsif ($rand_result <= 95) {
        $severity = 'severe';
    }
    else {
        $severity = 'critical';
    }

    #
    # It's cured eventually. Figure out 'eventually'
    #
    my $span = $duration_max - $duration_min + 1;
    my $length_of_sickness_for_this_case = $duration_min + int (rand ($span) + 1);

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

end_of_random_assignments:

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

#
# Return yes (1) or no (0)
#
sub predict_case_is_fatal {
    my $enable_use_of_owid_mortality_data = shift;
    my $mortality_table_ptr = shift;
    my $fixed_mortality = shift;
    my $local_begin_dt = shift;

    my $mortality;

    if ($enable_use_of_owid_mortality_data) {
        my $key = main::make_printable_date_string ($local_begin_dt);
        my $fp_val = $mortality_table_ptr->{$key};
        if (!(defined ($fp_val))) {
            print ("No value found in mortality hash table for $key\n");
            exit (1);
        }

        $mortality = $fp_val;
    }
    else {
        $mortality = $fixed_mortality;
    }

    my $mortality_x_10 = int ($mortality * 10);

    #
    # Get a random value between 1 and 1000 inclusive
    #
    my $random_mortality = int (rand (1000) + 1);
    if ($random_mortality <= $mortality_x_10) {
        #
        # Dies
        #
        return (1);
    }
    else {
        #
        # Lives
        #
        return (0);
    }
}

1;
