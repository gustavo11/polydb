#!/bin/env perl
# DO NOT USE THIS!!!!!! This version is reporting as polymorphic sites the 
# artifactual genotype calls from GATK like this:


# ChrIII_A_nidulans_FGSC_A4       1179032 .       C       .       4593.36 PASS    AC=0;AF=0.00;AN=2;DP=163;MQ=36.19;MQ0=1 GT:DP   0/0:162
# ChrIII_A_nidulans_FGSC_A4       1179032 .       CA      .       78.48   PASS    AC=0;AF=0.00;AN=2;DP=163;MQ=36.19;MQ0=1 GT:DP   0/0:162
# ???????????????????????????????????????????????

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

my $usage = "remove_homogeneous.pl <vcf_list> <new vcf_list>  <out>";

$log->logexit( $usage ) if ( scalar(@ARGV) != 3 );


my $vcf_file_list 		=  $ARGV[0];
my $new_vcf_file_list 		=  $ARGV[1];
my $pol_sites_file		=  $ARGV[2];


my @vcf_list;

my ( $refSampleNames, $refVCFList, $refNumCalls )  = VCFUtils::read_vcf_list( $vcf_file_list, $log );
@vcf_list = @{$refVCFList};


my %site;


####################
# Read all VCFs

for( my $ind = 0; $ind < scalar(@vcf_list); $ind++ ){
	my $vcf_file = $vcf_list[ $ind ];
	
	my $vcf_file_num = $ind + 1;
	my $progress_eta = $refNumCalls->[ $ind ];

	$log->info( "Reading data from $vcf_file [File num.: $vcf_file_num] ...\n" );
	
	# Only using progress bar if the number of insert and/or update lines
	# is higher than 100k
	my $progress;
	if( $progress_eta >= 100000 ){
		$progress = Term::ProgressBar->new( { count => $progress_eta, remove => 1 });
	}
	
		
	open IN, "$vcf_file";
	
	my $cont = 0;
	while( <IN> ){
		my $line = $_;
		next if $line =~ /^#/;
		chomp($line);
		my ($chrom,$pos,$id,$ref,$alt) = split '\t', $line;
		
		next if( length( $ref ) > 255 || length( $alt) > 255 );
		
		my $genotype = $alt;
		$genotype = $ref if $alt eq '.';
		
		$site{$chrom}{$pos}{$genotype} = 1;
		$site{$chrom}{$pos}{$ref} = 1;
		
		$progress->update( $cont ) if ( defined $progress && $cont % 1000 == 0 );
				
		$cont++;
	}
	
	close(IN);
	$progress->update( $progress_eta ) if( defined $progress );
}


# Printing all polymorphic sites (non homogeneous)
open OUT, ">$pol_sites_file" or die "Unable to open file $pol_sites_file!!!\n";

$log->info( "Identifying polymorphic sites ...\n" );

foreach my $chrom (keys %site){
		foreach my $pos (keys %{$site{$chrom}} ){
			my $num_genotypes = scalar( keys %{$site{$chrom}{$pos}} );			
			my $genotypes = join ( '-', keys %{$site{$chrom}{$pos}} ); 
			
			print OUT "$chrom\t$pos\t$num_genotypes\t$genotypes\n" if $num_genotypes > 1; 
		}
}
close(OUT);


####################
# Write new VCFs

my @new_num_calls;

# Add suffix .pol_sites.vcf
my @new_vcf_list = map { 
		my $value = $_;	
		if ( $value =~ /.vcf$/ ){
			$value =~ s/.vcf$/.pol_sites.vcf/;
			$value;
		}else{
			$value .=  ".pol_sites.vcf";
			$value;
		}
	} @vcf_list;

for( my $ind = 0; $ind < scalar(@vcf_list); $ind++ ){
	my $vcf_file = $vcf_list[ $ind ];
	my $vcf_output_file = $new_vcf_list[ $ind ];
	
	my $vcf_file_num = $ind + 1;
	my $progress_eta = $refNumCalls->[ $ind ];

	$log->info( "Generating a VCF containing only polymorphic sites found in $vcf_file [File num.: $vcf_file_num] ...\n" );
	
	# Only using progress bar if the number of insert and/or update lines
	# is higher than 100k
	my $progress;
	if( $progress_eta >= 100000 ){
		$progress = Term::ProgressBar->new( { count => $progress_eta, remove => 1 });
	}
	
	open IN, "$vcf_file" or log->fatal( "Unable to open file $vcf_file" ) ;
	open OUT, "$vcf_output_file" or log->fatal( "Unable to open file $vcf_output_file" ) ;
	
	my $cont = 0;
	while( <IN> ){
		my $line = $_;
		if( $line =~ /^#/ ){
			print OUT $line;
			next;
		}

		my ($chrom,$pos) = split '\t', $line;
		
		my $num_genotypes = scalar( keys %{$site{$chrom}{$pos}} );
		
		if( $num_genotypes > 1 ){
			print OUT $line;
			$new_num_calls[ $ind ]++;
		}

		$progress->update( $cont ) if ( defined $progress && $cont % 1000 == 0 );
				
		$cont++;
	}
	
	close(IN);
	$progress->update( $progress_eta ) if( defined $progress );
}

VCFUtils::write_vcf_list( $new_vcf_file_list , $refSampleNames, \@new_vcf_list, \@new_num_calls, $log );



