package GenotypeEquations;
use strict;

use Algorithm::Combinatorics qw(combinations);

sub expand {
	my ($genotype_equation) = @_;
	
	# Convert S0 to s0 and REF to ref
	$genotype_equation =~ s/S(\d+)/s$1/g;
	$genotype_equation =~ s/REF/ref/g;
	

	# Continuous expansion
	$genotype_equation =~
s/(s\d+|ref)\s*([=!]+)\s*s(\d+)\s*\.\.\s*s(\d+)\s*(\[\s*\d+\s*\])?/continuous_expansion($1,$2,$3,$4,$5)/ei;
	$genotype_equation =~
s/s(\d+)\s*\.\.\s*s(\d+)\s*(\[\s*\d+\s*\])?\s*([=!]+)\s*(s\d+|ref)/continuous_expansion($5,$4,$1,$2,$3)/ei;

	# List expansion
	$genotype_equation =~
s/(s\d+|ref)\s*([=!]+)\s*\(([\s*s\d+\s*,]+\s*s\d+\s*)\)\s*(\[\s*\d+\s*\])?/list_expansion($1,$2,$3,$4)/ei;
	$genotype_equation =~
s/\(([\s*s\d+\s*,]+\s*s\d+\s*)\)\s*(\[\s*\d+\s*\])?\s*([=!]+)\s*(s\d+|ref)/list_expansion($4,$3,$1,$2)/ei;

	# Expanding ref = s0 to (ref = s0 OR s0 = '' )
	$genotype_equation =~ s/ref\s*=\s*(s\d+)/( ref = \1 OR \1 = '' )/g;
	$genotype_equation =~ s/(s\d+)\s*=\s*ref/( ref = \1 OR \1 = '' )/g;

	# Expanding ref != s0 to (ref != s0 AND s0 != '' )
	$genotype_equation =~ s/ref\s*!=\s*(s\d+)/( ref != \1 AND \1 != '' )/g;
	$genotype_equation =~ s/(s\d+)\s*!=\s*ref/( ref != \1 AND \1 != '' )/g;

	
	# Adjusting field names
	$genotype_equation =~ s/ref/reference/g;
	$genotype_equation =~ s/s(\d+)/alt\[\1\]/g;
	
	$genotype_equation = "( " . $genotype_equation . " )";	

	return $genotype_equation;

}

sub continuous_expansion {
	my ( $operand1, $operator, $inisample, $lastsample, $arranjo_raw ) = @_;
	my ($arranjo) = ( $arranjo_raw =~ /\[\s*(\d+)\s*\]/ );

   #print "Arguments:\"$operand1\",\"$operator\",\"$inisample\",\"$lastsample\",\"$arranjo_raw\"\n";

	my $out = "( ";

	if ( $arranjo eq "" ) {
		for ( my $si = $inisample ; $si <= $lastsample ; $si++ ) {
			$out .= "$operand1 $operator s$si AND ";
		}
		$out =~ s/AND $/\)$arranjo/;
	}
	else {

		# scalar context gives an iterator
		my @items = ( $inisample .. $lastsample );
		
		my $iter = combinations( \@items, $arranjo );
		$out .= "( ";
		while ( my $p = $iter->next ) {
			for my $si ( @{$p} ) {
				$out .= "$operand1 $operator s$si AND ";
			}
			$out =~ s/AND $/\) OR \( /;
		}
		$out =~ s/OR \( $/\)/;
				
	}

	return "$out";
}

sub list_expansion {
	my ( $operand1, $operator, $list, $arranjo_raw ) = @_;

	my ($arranjo) = ( $arranjo_raw =~ /\[\s*(\d+)\s*\]/ );

	#print "Arguments:\"$operand1\",\"$operator\",\"$list\",\"$arranjo\"\n";

	my $out = "( ";
	my @items = ( $list =~ /s(\d+)/g );

	if ( $arranjo eq "" ) {
		for my $si (@items) {
			$out .= "$operand1 $operator s$si AND ";
		}
		$out =~ s/AND $/\)/;
	}
	else {

		# scalar context gives an iterator
		my $iter = combinations( \@items, $arranjo );
		$out .= "( ";
		while ( my $p = $iter->next ) {
			for my $si ( @{$p} ) {
				$out .= "$operand1 $operator s$si AND ";
			}
			$out =~ s/AND $/\) OR \( /;
		}
		$out =~ s/OR \( $/\)/;
	}

	return $out;
}

sub sample_list_to_negate_bit_string{
	my ( $refSampleArr, $num_samples ) = @_;
	
	my @bit_array = (1)x$num_samples;
	
	foreach my $sample ( @{$refSampleArr} ){
		my ($sample_num) = ( $sample =~ /s(\d+)/ );
		$bit_array[ $sample_num ] = 0; 
	} 
	my $bit_string = join( '', @bit_array); 
	return $bit_string;
} 

return 1;
