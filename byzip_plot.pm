#!/usr/bin/perl
package byzip_plot;
use warnings;
use strict;

#
# This file is part of byzip.pl. See information at the top of that file
#

use GD::Graph qw (black white green orange blue red);
use GD::Graph::points;
use GD::Graph::lines;
# use GD::Graph::colour;
use List::Util qw(min);

#
# Input:
#
#   $csv:
#
#      1st row: Date,New,Cured,Sick,UntestedSick,Dead,[repeat Cured..Dead],[repeat]
#      2nd row: YYYY-MM-DD, M, N, N, N, N (etc.)
#
#   $sims:
#
#      1 for the 1st Date..Dead plus one for each additional repeat
#
sub make_plot {
    my $dir = shift;
    my $csv_ptr = shift;
    my $max_cured = shift;
    my $title = shift;
    my $begin_display_dt = shift;

    my @csv_array = @$csv_ptr;
    
    my $debug_prints = 0;
    my $number_of_columns_per_sim = 4;
    my $graph_file = "$dir/graph.gif";
    if ($debug_prints) {
        print ("\$graph_file = $graph_file\n");
    }

    #
    # Remove the title row and count columns
    # Determine number of sims
    #
    my $column_titles = shift (@csv_array);
    my @columns = split (',', $column_titles);
    my $column_count = @columns;

    my $computed_number_of_sims = ($column_count - 2) / $number_of_columns_per_sim;

    my @data;

    # my $row_count_after_removing_date = @csv_array;
    # print ("\$row_count_after_removing_date = $row_count_after_removing_date\n");

    #
    # Make an array containing the 1st value in each row
    #
    my ($array_of_dates_ptr, $dates_to_skip, $new_csv_ptr) = make_array_of_dates (\@csv_array, $begin_display_dt);
    push (@data, $array_of_dates_ptr);
    @csv_array = @$new_csv_ptr;
    if ($debug_prints) {
        my $row_count_after_removing_date = @csv_array;
        print ("\$row_count_after_removing_date = $row_count_after_removing_date\n");
        my $top_row = $csv_array[0];
        my $row_length_after_removing_date = length ($top_row);
        print ("\$row_length_after_removing_date = $row_length_after_removing_date\n");
    }

    #
    # Make an array of new case counts
    #
    my ($array_of_new_cases_ptr, $new_csv_ptr_2) = make_array_of_new_cases (\@csv_array, $dates_to_skip);
    push (@data, $array_of_new_cases_ptr);
    @csv_array = @$new_csv_ptr_2;
    if ($debug_prints) {
        my $row_count_after_removing_case_count = @csv_array;
        print ("\$row_count_after_removing_case_count = $row_count_after_removing_case_count\n");
        my $top_row = $csv_array[0];
        my $row_length_after_removing_case_count = length ($top_row);
        print ("\$row_length_after_removing_case_count = $row_length_after_removing_case_count\n");
    }

    for (my $i = 0; $i < $computed_number_of_sims; $i++) {
        my ($cured_p, $sick_p, $untested_p, $dead_p, $new_csv_ptr_3) = get_sim_results (
            \@csv_array, $number_of_columns_per_sim, $dates_to_skip, $max_cured);
        @csv_array = @$new_csv_ptr_3;
        if ($debug_prints) {
            my $row_count_after_removing_a_sim = @csv_array;
            print ("\$row_count_after_removing_a_sim = $row_count_after_removing_a_sim\n");
            my $top_row = $csv_array[0];
            my $row_length_after_removing_a_sim = length ($top_row);
            print ("\$row_length_after_removing_a_sim = $row_length_after_removing_a_sim\n");
        }

        push (@data, $cured_p);
        push (@data, $sick_p);
        push (@data, $untested_p);
        push (@data, $dead_p);
    }

    # my @color_array = qw (black);
    # my @additional_color_array = qw (green orange blue red);
    # for (my $f = 0; $f <  $computed_number_of_sims; $f++) {
    #     push (@color_array, @additional_color_array);
    # }

    my $graph = GD::Graph::lines->new (1900, 750);
    $graph->set ( 
            x_label 	=> 'Dates', 
            y_label 	=> 'Cases', 
            title  		=> $title, 
            #cumulate 	=> 1, 
            # dclrs 		=> @color_array, 
            borderclrs 	=> [ qw(black black), qw(black black) ], 
            bar_spacing => 4, 
            transparent => 0,
            bgclr => 'white',
            line_width => 3,
            show_values => 0,
            x_labels_vertical => 1
    ) or die $graph->error; 

    if ($computed_number_of_sims == 1) {
        $graph->set ( 
            dclrs 		=> [qw(black green orange blue red)]
        );
    }
    elsif ($computed_number_of_sims == 3) {
        $graph->set ( 
            dclrs 		=> [qw(black green orange blue red green orange blue red green orange blue red)]
        );
    }
    elsif ($computed_number_of_sims == 5) {
        $graph->set ( 
            dclrs 		=> [qw(black green orange blue red green orange blue red green orange blue red green orange blue red green orange blue red)]
        );
    }

    #
    # @data is an array of arrays
    #
    my $gd = $graph->plot(\@data) or die $graph->error; 

    open(IMG, ">","$graph_file") or die $!;
    binmode IMG;
    print IMG $gd->gif;
    close IMG;

}

sub make_array_of_dates {
    my $ptr = shift;
    my $begin_display_dt = shift;

    my $first_reporting_date_string;
    if (!(defined ($begin_display_dt))) {
        $begin_display_dt = DateTime->new (year => 1800, month => 1, day => 1);
    }
    else {
        $first_reporting_date_string = sprintf ("%04d %02d %02d", $begin_display_dt->year(), $begin_display_dt->month(), $begin_display_dt->day());
    }

    my @return_array;
    my @csv = @$ptr;
    my $row_count = @csv;
    my @new_csv;
    my $dates_to_skip = 0;

    for (my $i = 0; $i < $row_count; $i++) {
        my $row = shift (@csv);
        my $i = index ($row, ',');
        my $date = substr ($row, 0, $i);
        my $remainder = substr ($row, $i + 1);
        push (@new_csv, $remainder);

        if ($date =~ /(\d{4})-(\d{2})-(\d{2})/) {
            my $display_dt = DateTime->new(
                    year       => $1,
                    month      => $2,
                    day        => $3);

            if ($display_dt < $begin_display_dt) {
                $dates_to_skip++;
                next;
            }
        }

        push (@return_array, $date);
    }

    return (\@return_array, $dates_to_skip, \@new_csv);
}

sub make_array_of_new_cases {
    my $ptr = shift;
    my $dates_to_skip = shift;

    my @csv = @$ptr;
    my $row_count = @csv;
    my @new_csv;
    my @return_array;

    for (my $i = 0; $i < $row_count; $i++) {
        my $row = shift (@csv);
        my $i = index ($row, ',');
        my $count = substr ($row, 0, $i);
        my $remainder = substr ($row, $i + 1);

        if ($dates_to_skip > 0) {
            $dates_to_skip--;
        }
        else {
            push (@return_array, $count);
        }

        push (@new_csv, $remainder);
    }

    return (\@return_array, \@new_csv);
}

sub get_sim_results {
    my ($csv_ptr, $number_of_columns_per_sim, $dates_to_skip, $max_cured) = @_;

    my @csv = @$csv_ptr;
    my $row_count = @csv;
    my @cured;
    my @sick;
    my @untested;
    my @dead;

    my @new_csv;

    for (my $i = 0; $i < $row_count; $i++) {
        my $row = shift (@csv);
        my @columns = split (',', $row);

        my $c = min (shift (@columns), $max_cured);
        my $s = shift (@columns);
        my $u = shift (@columns);
        my $d = shift (@columns);

        if ($dates_to_skip > 0) {
            $dates_to_skip--;
        }
        else {
            push (@cured, $c);
            push (@sick, $s);
            push (@untested, $u);
            push (@dead, $d);
        }
        
        my $new_row = join (',', @columns);

        push (@new_csv, $new_row);
    }

    return (\@cured, \@sick, \@untested, \@dead, \@new_csv);
}

1;
