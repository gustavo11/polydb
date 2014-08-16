#!/usr/bin/env perl

use lib "~gustavo/devel/vcf";
use lib "~gustavo/devel/lib";

use GenotypeEquations;
use VCFUtils;

use strict;

testing_genotype_equations();
#testing_alpha_order_alleles();
#testing_color_nt_array();

exit(0);

sub testing_color_nt_array{
	
	my @cols = qw(1 2 3 4 5 6);
	my @header = qw(chrom pos 0 1 2 3);
	
	my @arr = ( ["I", "200", "A", "T", "G,C", "A" ],  
	 			["I", "201", "T", "A", "T", "A" ],  
				["I", "202", "T", "AT", "T", "A" ] );
		
	my $out = VCFUtils::color_nt_array( \@arr, 2, 0, \@cols, \@header);
	
	print $out;  
}
sub testing_alpha_order_alleles{
	
	my $genotype = "T,A,G";
	
	print VCFUtils::alpha_order_alleles( $genotype ) . "\n";
}

sub testing_genotype_equations {

	#use re 'debug';
	#my $genotype_equation = " s0 != s1..s10 OR s1..s10 != s5 ";
	#my $genotype_equation = " s0 != ( s1, s2 ) OR (s3,s4) != s6 ";
	#my $genotype_equation = " s0 != ( s1, s2 )";

	#my $genotype_equation = " ( s0 != s1..s10 OR s1..s10 != s5 ) AND ( s0 != ( s1, s2 ) OR (s3,s4) != s6 )";
	#my $genotype_equation = "s0 != ( s1, s2, s3, s4 )[3]";
	#my $genotype_equation = "s1..s4 [3] != ref";
	my $genotype_equation = "s1 != s10..s47[3]";

	print $genotype_equation . "\n";
	$genotype_equation = GenotypeEquations::expand($genotype_equation);
	print $genotype_equation . "\n";
}

