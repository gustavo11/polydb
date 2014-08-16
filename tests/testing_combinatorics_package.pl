#!/usr/bin/env perl

use Algorithm::Combinatorics qw(combinations);

use strict;

#use re 'debug';

#my $word = " s0 != s1..s10 OR s1..s10 != s5 ";
#my $word = " s0 != ( s1, s2 ) OR (s3,s4) != s6 ";
#my $word = " s0 != ( s1, s2 )";

#my $word = " ( s0 != s1..s10 OR s1..s10 != s5 ) AND ( s0 != ( s1, s2 ) OR (s3,s4) != s6 )";
#my $word = "s0 != ( s1, s2, s3, s4 )[3]";
my $word = "s0 != s1..s4 [3]";

# Continuous expansion
$word =~ s/s(\d+)\s*([=!]+)\s*s(\d+)\s*\.\.\s*s(\d+)\s*(\[\s*\d+\s*\])?/continuous_expansion($1,$2,$3,$4,$5)/ei;
$word =~ s/s(\d+)\s*\.\.\s*s(\d+)\s*([=!]+)\s*s(\d+)\s*(\[\s*\d+\s*\])?/continuous_expansion($4,$3,$1,$2,$5)/ei;

# List expansion
$word =~ s/s(\d+)\s*([=!]+)\s*\(([\s*s\d+\s*,]+\s*s\d+\s*)\)\s*(\[\s*\d+\s*\])?/list_expansion($1,$2,$3,$4)/ei;
$word =~ s/\(([\s*s\d+\s*,]+\s*s\d+\s*)\)\s*([=!]+)\s*s(\d+)\s*(\[\s*\d+\s*\])?/list_expansion($3,$2,$1,$4)/ei;

print $word . "\n";

exit(0);


sub continuous_expansion{
        my ($operand1,$operator,$inisample,$lastsample,$arranjo_raw) = @_;

        my ($arranjo) = ( $arranjo_raw =~ /\[\s*(\d+)\s*\]/ );

        my $out = "( ";

        if( $arranjo eq "" ){
                for(my $si = $inisample; $si <= $lastsample; $si++ ){
                        $out .= "s$operand1 $operator s$si AND "
                }
                $out =~ s/AND $/\)$arranjo/;
        }else{
                # scalar context gives an iterator
                my @items = ($inisample .. $lastsample );

                my $iter = combinations(\@items,$arranjo);
                $out .= "( ";
                while (my $p = $iter->next) {
                        for my $si ( @{$p} ){
                                $out .= "s$operand1 $operator s$si AND "
                        }
                        $out =~ s/AND $/\) OR \( /;
                }
                $out =~ s/OR \( $/\)/;
        }


        return "$out";
}


sub list_expansion{
        my ($operand1,$operator,$list,$arranjo_raw) = @_;

        my ($arranjo) = ( $arranjo_raw =~ /\[\s*(\d+)\s*\]/ );
        print "Arguments:\"$operand1\",\"$operator\",\"$list\",\"$arranjo\"\n";

        my $out = "( ";
        my @items = ( $list =~ /s(\d+)/g );

        if( $arranjo eq "" ){
                for my $si ( @items ){
                        $out .= "s$operand1 $operator s$si AND "
                }
                $out =~ s/AND $/\)/;
        }else{
                # scalar context gives an iterator
                my $iter = combinations(\@items,$arranjo);
                $out .= "( ";
                while (my $p = $iter->next) {
                        for my $si ( @{$p} ){
                                $out .= "s$operand1 $operator s$si AND "
                        }
                        $out =~ s/AND $/\) OR \( /;
                }
                $out =~ s/OR \( $/\)/;
        }

        return $out;
}