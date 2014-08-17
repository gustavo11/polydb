#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin";

use lib $ENV{vcf_pm_dir};
use lib $ENV{cgibin_root};

use DBI;
use strict;
use VCFDB;
use VCFDB_OFFLINE;
use IO::Handle;
use casa_constants_for_installer;
use Log::Log4perl;

STDOUT->autoflush(1);

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

my $project_name  		= $ARGV[0];
my $keep_homogeneous_sites  	= $ARGV[1];
my $has_annotation	  	= $ARGV[2];
my $out           		= $ARGV[3];

my $usage = "$0 <project name> <keep homogeneous sites 1 = yes, 0 = no> <out sql file>";
die $usage if( scalar(@ARGV) != 4);

my $dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD )
  or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n" . DBI->errstr;

print "Checking number of samples stored in \'$project_name\'...\n";
my $num_samples_in_db = VCFDB::get_last_sample_num( $dbh, $project_name ) + 1;
$dbh->disconnect();


open OUT, ">$out" or die "ERROR: Unable to open file $out\n";

print OUT "BEGIN;\n";

# DEPRECATED
# This is being done as the first step of the pipeline
#if ( $keep_homogeneous_sites == 0 ){
#	print "\nRemoving records which all the samples have the same genotype ...\n";
#	print OUT VCFDB_OFFLINE::remove_homogeneous_records( $project_name, $num_samples_in_db );
#}

	
for ( my $sample_num = 0 ; $sample_num < $num_samples_in_db ; $sample_num++ ) {

	print "Working on sample $sample_num...\n";
			
	##### ONLY REALLY REQUIRED IF  IF THE DB HAS INDELS ########  
	print "\nAdjusting variance length on sample $sample_num...\n";
	print OUT VCFDB_OFFLINE::adjust_variance_length( $project_name, $sample_num );
		
	##### ONLY REALLY REQUIRED IF THE DB HAS TWO (OR MORE) ALLELES 
	##### CALLED IN THE SAME POS. : A,G ########
	print "\nAdjusting substitution type on sample $sample_num...\n";
	print "Genotype with two alleles are wrongly set as insertion.\n";
	print "Setting the substitution of those as ''.\n";
	print OUT VCFDB_OFFLINE::adjust_substitution_type( $project_name, $sample_num );

	# DEPRECATED
	# Brians scripts interpret those as deletion. Fixing it on old DATABASES. NOT NEED IT ANYMORE
	# 7000000184540634        41517   .       GA      .       134.83  PASS    AC=0;AF=0.00;AN=2;DP=125;MQ=54.80;MQ0=0 GT:DP   0/0:125 CDS,7000007077914484,7000007077914485,hypothetical protein,trans_orient:+,loc_in_cds:630,codon_pos:3,codon:ATG,DELETION[-1]
	#print OUT VCFDB_OFFLINE::fix_fake_variant( $project_name, $sample_num );
	# DEPRECATED

	# DEPRECATED - if modifcation in the code worked as expected. the default values
	# of alt fields should be '' 
	#print "\nSet samples with NULL ___alt field to an empty value...\n";
	#print "NULL value cannot be used in comparisons in a SQL command.\n";
	#print OUT VCFDB_OFFLINE::set_sample_values_equal_empty( $project_name, $sample_num );
	# DEPRECATED

	# THIS TAKE A REALLY LONG TIME IF ALL RECORDS (NOT ONLY HOMOGENEOUS RECORDS)
	# ARE PRESENT IN THE DATABASE
	print "\nSet samples with genotype equal to reference to an empty value...\n";
	print OUT VCFDB_OFFLINE::set_equal_ref_values_to_empty( $project_name, $sample_num );
		
}

print OUT VCFDB_OFFLINE::create_genotype_concat_field( $project_name );	
print OUT VCFDB_OFFLINE::populate_genotype_concat_field( $project_name, $num_samples_in_db );	

print OUT VCFDB_OFFLINE::create_genotype_concat_pipe_separated_field( $project_name );	
print OUT VCFDB_OFFLINE::populate_genotype_concat_pipe_separated_field( $project_name, $num_samples_in_db );	

print OUT VCFDB_OFFLINE::create_num_samples_diff_reference_field( $project_name );	
print OUT VCFDB_OFFLINE::populate_num_samples_diff_reference_field( $project_name, $num_samples_in_db );	

print OUT VCFDB_OFFLINE::create_diff_reference_field( $project_name, $num_samples_in_db );	
print OUT VCFDB_OFFLINE::populate_diff_reference_field( $project_name, $num_samples_in_db );	

print OUT "COMMIT;\n";
close(OUT);



