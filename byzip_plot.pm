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
#      1st row: Date,New,Cured,Infectious,Sick,UntestedSick,Dead,[repeat Cured..Dead],[repeat]
#      2nd row: YYYY-MM-DD, M, N, N, N, N (etc.)
#
#   $sims:
#
#      1 for the 1st Date..Dead plus one for each additional repeat
#
sub make_plot {
    my $dir = shift;
    my $csv_ptr = shift;
    my $number_of_nonsim_columns = shift;
    my $number_of_columns_per_sim = shift;
    my $max_cured = shift;
    my $title = shift;
    my $begin_display_dt = shift;

    my @csv_array = @$csv_ptr;
    
    my $debug_prints = 1;

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

    my $computed_number_of_sims = ($column_count - $number_of_nonsim_columns) / $number_of_columns_per_sim;
    if ($debug_prints) {
        print ("\$computed_number_of_sims = $computed_number_of_sims\n");
    }

    my @data;

    my $initial_row_count = @csv_array;
    my $top_row = $csv_array[0];
    my $initial_row_comma_count = $top_row =~ tr/,/,/;

    # my $row_count_after_removing_date = @csv_array;
    # print ("\$row_count_after_removing_date = $row_count_after_removing_date\n");

    #
    # Make an array containing the 1st value in each row
    #
    my ($array_of_dates_ptr, $dates_to_skip, $new_csv_ptr) = make_array_of_dates (\@csv_array, $begin_display_dt);
    push (@data, $array_of_dates_ptr);
    print ("Added date array\n");
    @csv_array = @$new_csv_ptr;
    my $row_count_after_removing_date = @csv_array;
    $top_row = $csv_array[0];
    my $row_comma_count_after_removing_date = $top_row =~ tr/,/,/;
    if ($row_comma_count_after_removing_date != $initial_row_comma_count - 1) {
        print ("\$row_count_after_removing_date = $row_count_after_removing_date\n");
        print ("\$row_comma_count_after_removing_date = $row_comma_count_after_removing_date\n");
        die;
    }

    #
    # Make an array of new case counts
    #
    my ($array_of_new_cases_ptr, $new_csv_ptr_2) = make_array_of_new_cases (\@csv_array, $dates_to_skip);
    push (@data, $array_of_new_cases_ptr);
    print ("Added new cases array\n");
    @csv_array = @$new_csv_ptr_2;
    my $row_count_after_removing_case_count = @csv_array;
    $top_row = $csv_array[0];
    my $row_comma_count_after_removing_case_count = $top_row =~ tr/,/,/;
    if ($row_comma_count_after_removing_case_count != $row_comma_count_after_removing_date - 1) {
        print ("\$row_count_after_removing_case_count = $row_count_after_removing_case_count\n");
        print ("\$row_comma_count_after_removing_case_count = $row_comma_count_after_removing_case_count\n");
        die;
    }

    my $previous_row_comma_count = $row_comma_count_after_removing_case_count;
    my $last_sim = 0;
    for (my $i = 0; $i < $computed_number_of_sims; $i++) {
        if ($i == $computed_number_of_sims - 1) {
            $last_sim = 1;
        }

        my ($cured_p, $infectious_p, $sick_p, $untested_p, $dead_p, $new_csv_ptr_3) =
            get_sim_results (
                \@csv_array,
                $number_of_columns_per_sim,
                $dates_to_skip,
                $max_cured
            );
        @csv_array = @$new_csv_ptr_3;
        my $row_count_after_removing_a_sim = @csv_array;
        $top_row = $csv_array[0];
        my $row_comma_count_after_removing_a_sim = $top_row =~ tr/,/,/;
        if ($last_sim) {
            if ($row_comma_count_after_removing_a_sim != 0) {
                die;
            }
        }
        elsif ($row_comma_count_after_removing_a_sim != $previous_row_comma_count - $number_of_columns_per_sim) {
            print ("\$row_comma_count_after_removing_a_sim = $row_comma_count_after_removing_a_sim\n");
            print ("\$previous_row_comma_count = $previous_row_comma_count\n");
            print ("\$row_count_after_removing_a_sim = $row_count_after_removing_a_sim\n");
            die;
        }
        else {
            $previous_row_comma_count = $row_comma_count_after_removing_a_sim;
        }

        #
        # Order of results: Cured,Infectious,Sick,UntestedSick,Dead
        #

        push (@data, $cured_p);
        push (@data, $infectious_p);
        push (@data, $sick_p);
        push (@data, $untested_p);
        push (@data, $dead_p);
        print ("Added 5 sim arrays\n");
    }

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

    #
    # Order of results: Cured,Infectious,Sick,UntestedSick,Dead
    #
    my @color_array = qw (black);   # for new cases
    my @additional_color_array = qw (green purple orange blue red);
    for (my $f = 0; $f < $computed_number_of_sims; $f++) {
        push (@color_array, @additional_color_array);
    }

    $graph->set ( 
        dclrs => \@color_array
    );


    #
    #
    #
    my $array_of_dates = $data[0];
    my $first_array_of_results = $data[1];
    my $len0 = @$array_of_dates;
    my $len1 = @$first_array_of_results;
    my $len_of_color_array = @color_array;
    my $len_of_data_array = @data;
    if ($len0 != $len1) {
        print ("Lens dont match\n");
        print ("\$len0 = $len0\n");
        print ("\$len1 = $len1\n");
        die;
    }

    if ($len_of_color_array != $len_of_data_array - 1) {
        print ("Color lens dont match\n");
        print ("\$len_of_color_array = $len_of_color_array\n");
        print ("\$len_of_data_array = $len_of_data_array\n");
        die;
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

    #
    # Debug
    #
    my $temp = $csv[0];
    if ($temp =~ /\d{4}-\d{2}-\d{2}/) {
        print ("In make_array_of_new_cases(), found a date string in the csv array\n");
        die;
    }

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

#
# Order of results: Cured,Infectious,Sick,UntestedSick,Dead
#
sub get_sim_results {
    my ($csv_ptr, $number_of_columns_per_sim, $dates_to_skip, $max_cured) = @_;

    my @csv = @$csv_ptr;
    my $row_count = @csv;
    my @cured;
    my @infectious;
    my @sick;
    my @untested;
    my @dead;

    my @new_csv;

    #
    # Debug
    #
    my $temp = $csv[0];
    if ($temp =~ /\d{4}-\d{2}-\d{2}/) {
        print ("In get_sim_results(), found a date string in the csv array\n");
        die;
    }

    for (my $i = 0; $i < $row_count; $i++) {
        my $row = shift (@csv);
        my @columns = split (',', $row);

        my $cu = min (shift (@columns), $max_cured);
        my $inf = shift (@columns);
        my $sk = shift (@columns);
        my $un = shift (@columns);
        my $de = shift (@columns);

        if ($dates_to_skip > 0) {
            $dates_to_skip--;
        }
        else {
            push (@cured, $cu);
            push (@infectious, $inf);
            push (@sick, $sk);
            push (@untested, $un);
            push (@dead, $de);
        }
        
        my $new_row = join (',', @columns);

        push (@new_csv, $new_row);
    }

    return (\@cured, \@infectious, \@sick, \@untested, \@dead, \@new_csv);
}

1;
