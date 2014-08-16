#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin";

use VCFDB_OFFLINE;
use Carp;
use Log::Log4perl;
use Term::ProgressBar;
use IPCHelper;
use VCFUtils;
use strict;


# Starting logging
#sub getFileMode{ return "append"; };
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

my $usage = "$0 <vcf file list> <genome fasta> <gff> \n\n";

die $usage if ( scalar(@ARGV) != 3 );

my $vcf_file_list 	= $ARGV[0];
my $genome_fasta  	= $ARGV[1];
my $gff			= $ARGV[2];




##############################################################
# Read VCF LIST

my @vcf_list;
my @sample_names;
my @vcf_num_calls;
my %sample_id;


# Just get the number of calls from vcf_list
my ( $refSampleNames, $refVCFList, $refNumCalls, $refSampleId )  = VCFUtils::read_vcf_list( $vcf_file_list, $log );
@vcf_list 	= @{$refVCFList};
@sample_names 	= @{$refSampleNames};
@vcf_num_calls	= @{$refNumCalls};
%sample_id 	= %{$refSampleId};


##############################################################

my $vcf_file_num = 1;
foreach my $vcf_file (@vcf_list) {

	$log->info( "Annotating $vcf_file [File num.: $vcf_file_num] ...\n" );
		
	my $cmd = $FindBin::Bin . "/vcfannotator/VCF_annotator.pl";
	my $vcf_annot = $vcf_file . '.annot';
	$vcf_annot =~ s{.*/}{};
	
	IPCHelper::SetEnvAndRunCmdNoOutBuffer( [ $cmd, 
						   '--gff3', $gff,
						   '--genome', $genome_fasta,
						   '--vcf', $vcf_file,
						   '--out', $vcf_annot ],
						   "Unable to annotate $vcf_file!" );

	$vcf_file_num++;
}

