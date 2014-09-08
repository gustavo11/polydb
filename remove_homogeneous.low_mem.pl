#!/bin/env perl

use FindBin;
use lib "$FindBin::Bin";

use Log::Log4perl;
use Term::ProgressBar;
use VCFUtils;
use File::Basename;

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

my $usage = "remove_homogeneous.pl <vcf_list> <new vcf_list> <out>";

$log->logexit( $usage ) if ( scalar(@ARGV) != 3 );


####################
# Read VCF list

my $vcf_file_list 		=  $ARGV[0];
my $new_vcf_file_list 		=  $ARGV[1];
my $pol_sites_file		=  $ARGV[2];

my @vcf_list;

my ( $refSampleNames, $refVCFList, $refNumCalls )  = VCFUtils::read_vcf_list( $vcf_file_list, $log );
@vcf_list = @{$refVCFList};




my %polymorphic_sites;

####################
# Read all VCFs


for( my $ind = 0; $ind < scalar(@vcf_list); $ind++ ){
	my $vcf_file = $vcf_list[ $ind ];
	
	# If NOT full path (starting with '/')
	# then add the path of vcf_list file to the path of each VCF
	if( $vcf_file !~ /^\// ){
		my ($void, $vcf_list_path, $void ) = fileparse( $vcf_file_list );
		$vcf_file = $vcf_list_path . $vcf_file;
	}	
	
	my $vcf_file_num = $ind + 1;
	my $progress_eta = $refNumCalls->[ $ind ];

	$log->info( "Reading data from $vcf_file [File num.: $vcf_file_num] ...\n" );
	
	# Only using progress bar if the number of insert and/or update lines
	# is higher than 100k
	my $progress;
	if( $progress_eta >= 100000 ){
		$progress = Term::ProgressBar->new( { count => $progress_eta, remove => 1 });
	}
	
		
	open IN, "$vcf_file" or die "Unable to open file $vcf_file!!!\n";;
	
	my $cont = 0;
	while( <IN> ){
		my $line = $_;
		next if $line =~ /^#/;
		chomp($line);
		my ($chrom,$pos,$id,$ref,$alt) = split '\t', $line;
		
		next if( length( $ref ) > 255 || length( $alt) > 255 );
		
		$polymorphic_sites{$chrom}{$pos} = 1 if ( $alt ne '.' );
				
		$progress->update( $cont ) if ( defined $progress && $cont % 1000 == 0 );				
		$cont++;
	}
	
	close(IN);
	$progress->update( $progress_eta ) if( defined $progress );
}


# Printing all polymorphic sites (non homogeneous)
open OUT, ">$pol_sites_file" or die "Unable to open file $pol_sites_file!!!\n";

$log->info( "Reporting polymorphic sites ...\n" );

foreach my $chrom (keys %polymorphic_sites){
		foreach my $pos (keys %{$polymorphic_sites{$chrom}} ){
			
			print OUT "$chrom\t$pos\n"; 
		}
}
close(OUT);


####################
# Write new VCFs

my @new_num_calls;

# Add suffix .pol_sites.vcf
my @new_vcf_list = map { 
		my $vcf_file = $_;	

		$vcf_file =~ s{.*/}{};
				
		if ( $vcf_file =~ /.vcf$/ ){
			$vcf_file =~ s/.vcf$/.pol_sites.vcf/;
			$vcf_file;
		}else{
			$vcf_file .=  ".pol_sites.vcf";
			$vcf_file;
		}
	} @vcf_list;

for( my $ind = 0; $ind < scalar(@vcf_list); $ind++ ){
	my $vcf_file = $vcf_list[ $ind ];
	
	# If NOT full path (starting with '/')
	# then add the path of vcf_list file to the path of each VCF
	if( $vcf_file !~ /^\// ){
		my ($void, $vcf_list_path, $void ) = fileparse( $vcf_file_list );
		$vcf_file = $vcf_list_path . $vcf_file;
	}		
	
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
	
	open IN, "$vcf_file" or $log->fatal( "Unable to open file $vcf_file" ) ;
	open OUT, ">$vcf_output_file" or $log->fatal( "Unable to open file $vcf_output_file" ) ;
	
	my $cont = 0;
	while( <IN> ){
		my $line = $_;
		if( $line =~ /^#/ ){
			print OUT $line;
			next;
		}

		my ($chrom,$pos) = split '\t', $line;
		
		if( $polymorphic_sites{$chrom}{$pos} == 1 ){
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


