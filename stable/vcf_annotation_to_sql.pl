#!/usr/bin/env perl

use lib $ENV{vcf_pm_dir};
use lib $ENV{cgibin_root};

use FindBin;
use lib "$FindBin::Bin";

use DBI;
use VCFDB;
use VCFDB_OFFLINE;
use Carp;
use casa_constants_for_installer;
use Log::Log4perl;
use Term::ProgressBar;


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

my $vcf_file_list       	= $ARGV[0];
my $keep_invariant_sites	= $ARGV[1];
my $table         		= $ARGV[2];
my $output        		= $ARGV[3];
my $bb_out        		= $ARGV[4];

my $usage = "$0 <vcf file list> <project name> <output> " .
            " <output file containing SQL cmd to upload all the info added by Brian's script into <project_name>_full_annot table>\n\n";

die $usage if ( scalar(@ARGV) != 5 );

# Table containing full annotation
my $full_annot_table = $table . "_full_annot";


##############################################################
# Read VCF LIST

my @vcf_list;
my @sample_names;
my @vcf_num_calls;
my %sample_id;


# Just get the number of calls from vcf_list
my ( $refSampleNames, $refVCFList, $refNumCalls, $refSampleId )  = VCFUtils::read_vcf_list( $vcf_file_list, $log );
@vcf_num_calls	= @{$refNumCalls};
@vcf_list 	= @{$refVCFList};
@sample_names 	= @{$refSampleNames};
%sample_id 	= %{$refSampleId};



##############################################################


open OUT, ">$output" or die "Unable to open file $output\n";
open BB_OUT, ">$bb_out" or die "Unable to open file $bb_out\n";

# BEGIN and COMMIT turns off autocommit
print OUT "BEGIN;\n";
print BB_OUT "BEGIN;\n";

$log->info( "Checking number of samples stored in \'$table\'...\n" );

# Changing DB
my $dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD )
  or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n" . DBI->errstr;

my $num_samples_in_db = VCFDB::get_last_sample_num( $dbh, $table ) + 1;


# Read polymorphic sites file
#my %sites;
#if ( $keep_invariant_sites == 0 ){
#	my $refSites = VCFUtils::read_pol_sites( $table );
#	%sites = %{$refSites};
#}



# Deprecated - this code is already part of vcf2sql
#my $query = VCFDB_OFFLINE::generate_gene_annotation_fields_indexes( $table );
#print OUT $query . "\n";
#$query = VCFDB_OFFLINE::generate_gene_annotation_fields_indexes_for_samples( $table, $num_samples_in_db );
#print OUT $query . "\n";
# Deprecated - this code is already part of vcf2sql

my $vcf_file_num = 1;
foreach my $vcf_file (@vcf_list) {
	
	my $vcf_annot = $vcf_file . '.annot';
	$vcf_annot =~ s{.*/}{};

	$log->info( "Reading data from $vcf_annot [File num.: $vcf_annot] ...\n" );
	
	my $progress_eta = $vcf_num_calls[ $vcf_file_num - 1 ];
	
	# Only using progress bar if the number of insert and/or update lines
	# is higher than 100k
	my $progress;
	if( $progress_eta >= 100000 ){
		$progress = Term::ProgressBar->new( { count => $progress_eta, remove => 1 });
	}

	

	open IN, "$vcf_annot" or $log->fatal( "Unable to open file $vcf_annot\n" );
	my $line_num = 0;
	while (<IN>) {
		my $line = $_;
		$line_num++;
		
		#print STDERR "$line_num/$progress_eta\n"; 
		$progress->update( $line_num ) 
			 if( defined $progress && $line_num % 10000 == 0 );				

			 
		next if $line =~ /^#/; 

		chomp $line;
		my @cols = split "\t", $line;

		next if $line =~ /^\s*$/;

		# Error line found
		if ( $line =~ /^!! ERROR !!/ || $line =~ /^Error/ ) {
			;
			print STDERR "\nWarning: error line found!!!!\n";
			print STDERR "Line number:$line_num\n\t$line\n";
			next;
		}

		#print ".";

		# Next if more than one CDS info per line
		#if( scalar(@cols) != 11 ){
		#print STDERR "\nWarning: More than one CDS per line!!!!\n";
		#print STDERR $line . "\n";
		#next;
		#}

		my $ref_seq      = $cols[0];
		my $ref_coord    = $cols[1];
		my $reference    = $cols[3];
		my $substitution = $cols[4];
		
		# Discard if not polymorphic site
		#next if( $keep_invariant_sites == 0 && not defined $sites{$ref_seq}{$ref_coord} );


		# Skip if no call
		next if ( length($reference) == 1 && $substitution eq "." );

# Polymorphism attributes which are independent of structural annotation of genome (gene boundaries)
		my $length_final;
		my $variance_type_final;

	 # Concatenation of attributes which depend on structural annotation of genome (gene boundaries)
		my $gene_concat       = "";
		my $annotation_concat = "";
		my $syn_nsyn_concat   = "";

		#print "....";
		#getc();

		# Iterate through the additional columns added by Brian's script
		my $cont_bcols    = 1;
		my $skipping = 0;
		foreach my $brians_col ( @cols[ 10 .. $#cols ] ) {

			#print "2....";
			#getc();
 
            #######################
			# Skip if intergenic or if fake variation like those lines below. Brians scripts interpret those as deletion
# 7000000184540634        41517   .       GA      .       134.83  PASS    AC=0;AF=0.00;AN=2;DP=125;MQ=54.80;MQ0=0 GT:DP   0/0:125 CDS,7000007077914484,7000007077914485,hypothetical protein,trans_orient:+,loc_in_cds:630,codon_pos:3,codon:ATG,DELETION[-1]		

			if ( $brians_col =~ /^intergenic/ || $substitution eq "." ) {
				$skipping = 1;
				last;
			}

			#print $brians_col . "\n";

			# If a deletion

#NC_003228.3     43697   .       TA      T       1181.68 PASS    AC=2;AF=1.00;AN=2;DP=34;FS=0.000;HRun=4;HaplotypeScore=297.2827;MQ=49.57;MQ0=0;QD=34.76;SB=-539.34      GT:AD:DP:GQ:PL1/1:0,34:34:99:1224,102,0        CDS,7000001212825068,7000001212825069,hypothetical protein,trans_orient:+,loc_in_cds:890,codon_pos:2,codon:ATA,DELETION[-1] CDS,7000001212825068,7000001212825069,hypothetical protein,+,890,2,ATA,DELETION[-1],1

			my (
				$feat,             $gene,    $transcript, $annotation,
				$strand,           $cds_pos, $codon_pos,  $codon_modification,
				$pep_modification, $summary, $syn_nsyn
			);

			my $length;
			my $variance_type;
			my $syn_nsyn;

			if( $brians_col =~ /^p5UTR/ || $brians_col =~ /^p3UTR/ || $brians_col =~ /^intron/ ){
				
				my @bcols = ( $brians_col =~ /(\S+?),(\S+?),(\S+?),([\w\W]+?),([+-])/ );
				print STDERR
"ERROR: UTR/INTRO parser. Unable to parse Brian's col number $cont_bcols\n Brian's col: $brians_col\n line:\n $line \n"
				  if scalar(@bcols) != 5;

				(
					$feat,       $gene,               $transcript,
					$annotation, $strand
				) = @bcols;
				
				$length = length($reference) - length($substitution);
				$variance_type = "DELETION" if $length > 0;
				$variance_type = "INSERTION" if $length < 0;
				$variance_type = "SUBSTITUTION" if $length == 0;
				$syn_nsyn      = $feat;
				
#print "$line\n";
#print "$feat,$gene,$transcript,$annotation,$strand,$cds_pos,$codon_pos,$codon_modification,$length\n";
#getc();
				
				
				 
			}elsif ( length($reference) > length($substitution) ) {
				my @bcols =
				  ( $brians_col =~
/(\S+?),(\S+?),(\S+?),([\w\W]+?),trans_orient:([+-]),loc_in_cds:(\d+),codon_pos:(\d+),codon:([\w\W]+),([\w\W]+)/
				  );
				print STDERR
"ERROR: Deletion parser. Unable to parse Brian's col number $cont_bcols\n Brian's col: $brians_col\n line:\n $line \n"
				  if scalar(@bcols) != 9;

				(
					$feat,       $gene,               $transcript,
					$annotation, $strand,             $cds_pos,
					$codon_pos,  $codon_modification, $summary
				) = @bcols;

				($length) = ( $summary =~ /DELETION\[-(\d+)\]/ );
				$variance_type = "DELETION";
				$syn_nsyn      = "INDEL";

#print "$line\n";
#print "$feat,$gene,$transcript,$annotation,$strand,$cds_pos,$codon_pos,$codon_modification,$substitution_type,$length\n";
#getc();

				# If an insertion

#NC_003228.3     139685  .       T       TA      4011.31 PASS    AC=2;AF=1.00;AN=2;DP=109;FS=0.000;HRun=5;HaplotypeScore=409.8267;MQ=60.37;MQ0=0;QD=36.80;SB=-1837.08    GT:AD:DP:GQ:PL1/1:6,103:109:99:4011,310,0      CDS,7000001212825369,7000001212825370,hypothetical protein,trans_orient:-,loc_in_cds:126,codon_pos:3,codon:TTA,INSERTION[1] CDS,7000001212825369,7000001212825370,hypothetical protein,-,126,3,TTA,INSERTION[1],1

			}
			elsif ( length($reference) < length($substitution) ) {
				my @bcols =
				  ( $brians_col =~
/(\S+?),(\S+?),(\S+?),([\w\W]+?),trans_orient:([+-]),loc_in_cds:(\d+),codon_pos:(\d+),codon:([\w\W]+),([\w\W]+)/
				  );
				die
"ERROR: Insertion parser. Unable to parse Brian's col number $cont_bcols\n Brian's col: $brians_col\n line:\n $line \n"
				  if scalar(@bcols) != 9;

				(
					$feat,       $gene,               $transcript,
					$annotation, $strand,             $cds_pos,
					$codon_pos,  $codon_modification, $summary
				) = @bcols;

				($length) = ( $summary =~ /INSERTION\[(\d+)\]/ );
				$variance_type = "INSERTION";
				$syn_nsyn      = "INDEL";

#print "$line\n";
#print "$feat,$gene,$transcript,$annotation,$strand,$cds_pos,$codon_pos,$codon_modification,$substitution_type,$length\n";
#getc();

			}
			else {
				my @bcols =
				  ( $brians_col =~
/(\S+?),(\S+?),(\S+?),([\w\W]+?),trans_orient:([+-]),loc_in_cds:(\d+),codon_pos:(\d+),codon:([\w\W]+),pep:([\w\W]+),([\w\W]+),\(([\w\W]+)\)/
				  );

				
				my @bcols2 =
				  ( $brians_col =~
/(\S+?),(\S+?),(\S+?),([\w\W]+?),trans_orient:([+-]),loc_in_cds:(\d+),codon_pos:(\d+),codon:([\w\W]+)/
				  );
				  
				print STDERR
"ERROR: Substitution parser. Unable to parse Brian's col number $cont_bcols\n Brian's col: $brians_col\n line:\n $line \n"
				  if ( scalar(@bcols) != 11 && scalar(@bcols2) != 8 );


				if( scalar(@bcols) == 11 ){
				(
					$feat,       $gene,               $transcript,
					$annotation, $strand,             $cds_pos,
					$codon_pos,  $codon_modification, $pep_modification,
					$summary,    $syn_nsyn
				) = @bcols;

				$length        = 0;
				$variance_type = "SUBSTITUTION";
				}elsif( scalar(@bcols2) == 8 ){
					(
					$feat,       $gene,               $transcript,
					$annotation, $strand,             $cds_pos,
					$codon_pos,  $codon_modification
					) = @bcols2;
					$length        = 0;
					$variance_type = "SUBSTITUTION";
					$syn_nsyn = "TRUNCATED";
					
				}else{
					print STDERR "ERROR: Substitution parser. Unable to parse Brian's col number $cont_bcols\n Brian's col: $brians_col\n line:\n $line \n";
				}
					
					

#print "$feat,$gene,$transcript,$annotation,$strand,$cds_pos,$codon_pos,$codon_modification,$pep_modification,$summary,$substitution_type\n";
#getc();

			}

			# Unable to identify variance type
			if ( $variance_type eq "" ) {
				print STDERR "\nWarning: Unable to identify variance type!!!!\n";
				print STDERR $line . "\n";
				next;
			}

			# Unable to define length
			if ( not $length =~ /\d+/ ) {
				print STDERR "\nWarning: Unable to define length: >>>$length<<< !!!!\n";
				print STDERR $line . "\n";
				next;
			}

			# Difference variance type between two brian cols
			if ( $variance_type_final ne "" ) {
				if( $variance_type ne $variance_type_final ){
					print STDERR	
					"ERROR: Different variance_type (SUBSTITUTION,DELETION,INSERTION) on two of the columns added by Brian's script\n$line\n";
					print STDERR "Variance type of the current column: \'$variance_type\'\n";
					print STDERR "Variance type from previous columns: \'$variance_type_final\'\n";
					getc();
				} 
			}
			else {
				$variance_type_final = $variance_type;
			}

			# Difference length between two brian cols
			if ( $length_final ne "" ) {
				print STDERR
"ERROR: Different variance length on two of the columns added by Brian's script:\ncurr:$line\nprevious:$length_final\n$line"
				  if $length != $length_final;
			}
			else {
				$length_final = $length;
			}

			$gene_concat       .= $gene . "::";
			$annotation_concat .= $annotation . "::";
			$syn_nsyn_concat   .= $syn_nsyn . "::";
			$cont_bcols++;

		}
		
		
		# If not intergenic
		if( $skipping == 0 ){

		$gene_concat       =~ s/::$//;
		$annotation_concat =~ s/::$//;
		$syn_nsyn_concat   =~ s/::$//;

		$annotation_concat =~ s/\'/\'\'/g;
		
		my $curr_sample_id = $sample_id{$vcf_file};
		die "ERROR: Sample id for file $vcf_file not found!" if not defined( $curr_sample_id ); 

		my $cmd =
		    "update $table set gene = \'$gene_concat\', "
		  . "gene_annotation = \'$annotation_concat\', " 
		  . "var_syn_nsyn[ " . $curr_sample_id . " ] = \'$syn_nsyn_concat\' "
		  . " where chrom = \'$ref_seq\' AND position =  $ref_coord AND reference = \'$reference\'"
		  . " and var_type = \'$variance_type_final\';";

		#print $cmd . "\n";
		#print $line . "\n";
		print OUT $cmd . "\n";

		# Everything added by Brian's script in a single column 
		my $full_annot = join( " ", @cols[ 10 .. $#cols ] );
		
		$full_annot =~ s/\'/\'\'/g;
		
		$cmd =
		    "update $full_annot_table set " 
		  . " full_annot[" . $curr_sample_id . "] = \'$full_annot\' "
		  . " where chrom = \'$ref_seq\' AND position =  $ref_coord AND reference = \'$reference\'"
		  . " and var_type = \'$variance_type_final\';";
		print BB_OUT $cmd . "\n";


		}
		

		#getc();
		
		$progress->update( $progress_eta ) if( defined $progress );
	}

	close(IN);
	$vcf_file_num++;
}
# BEGIN and COMMIT turns off autocommit
print OUT "COMMIT;\n";
print BB_OUT "COMMIT;\n";
close(OUT);
close(BB_OUT);
