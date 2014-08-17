#!/bin/env perl

use FindBin;
use lib "$FindBin::Bin";

use Log::Log4perl;
use Term::ProgressBar;
use VCFUtils;

use strict;


Log::Log4perl->init( $FindBin::Bin . '/log4perl.conf' );
my $log = Log::Log4perl->get_logger();

$SIG{__WARN__} = sub {
        local $Log::Log4perl::caller_depth =
        $Log::Log4perl::caller_depth + 1;
        $log->warn( @_ );
};

$SIG{__DIE__} = sub {
        if($^S) {
        	# We're in an eval {} and don't want log
        	# this message but catch it later
        	return;
        }
        $Log::Log4perl::caller_depth++;
        $log->logexit( @_ );
};

my $usage = "estimate_size_vcf_files.pl <vcf_list>";

$log->logexit( $usage ) if ( scalar(@ARGV) != 1 );


my $vcf_file_list =  $ARGV[0];


my ( $refSampleNames, $refVCFList, $refNumCalls )  = VCFUtils::read_vcf_list( $vcf_file_list, $log );


for( my $ind = 0; $ind < scalar(@{$refVCFList}); $ind++ ){
	my $vcf_file = $refVCFList->[ $ind ];
	
	my $vcf_file_num = $ind + 1;
	
	if( not defined $refNumCalls->[ $ind ] ){
		
		$log->info( "Counting number of genotype calls in $vcf_file [File num.: $vcf_file_num] ...\n" );
		my $num_genotype_calls = `wc -l < $vcf_file`;
		chomp $num_genotype_calls;
		$log->info( "Done count\n" );
		
		$refNumCalls->[ $ind ] = $num_genotype_calls;
	}
}

VCFUtils::write_vcf_list( $vcf_file_list, $refSampleNames, $refVCFList, $refNumCalls );


