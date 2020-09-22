#!/usr/bin/perl
package byzip_cleanups;
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

#
# If a row value is wrapped in double quotes, remove the double quotes
# Sometimes row values are wrapped in double quotes but also contain commas
# These will not be changed
#
# Example:
#
#    ,"4" becomes 4
#    ,"tom, dick, harry", will be split into "tom
#                                             dick
#                                             harry"
#
sub remove_double_quotes_from_column_values {
    my $record = shift;

    my @list = split (',', $record);
    my $len = @list;
    for (my $i = 0; $i < $len; $i++) {
        my $val = $list[$i];
        if ($val =~ /^\"/ && $val =~ /\"\z/) {
            my $new_val = substr ($val, 1, length ($val) - 2);
            $list[$i] = $new_val;
        }
    }
    $record = join (',', @list);

    return ($record);
}

#
# If a field is wrapped in double quotes and it contains commas within the quotes,
# convert the commas to dashes and delete the double quotes
#
# This needs to be done prior to the split below or the commas will mess up the
# count of columns for the record
#
sub remove_commas_from_double_quoted_column_values {
    my ($record) = @_;
    
    my $left_double_quote = index ($record, '"');
    if ($left_double_quote == -1) {
        return ($record);
    }

    my $right_double_quote = index ($record, '"', $left_double_quote + 1);
    if ($right_double_quote == -1) {
        print ("Record has a single double quote\n");
        exit (1);
    }

    my $len = $right_double_quote - $left_double_quote;
    my $temp = substr ($record, $left_double_quote + 1, $len - 1);

    # print ("  \$temp = $temp\n");

    $temp =~ s/, /-/g;
    $temp =~ s/,/-/g;

    my $left_half = substr ($record, 0, $left_double_quote);
    my $right_half = substr ($record, $right_double_quote + 1);

    return (remove_commas_from_double_quoted_column_values (
        $left_half . $temp . $right_half));
}

1;
