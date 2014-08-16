#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin";

use lib $ENV{cgibin_root};

use DBI;
use strict;
use VCFDB;
use IO::Handle;
use Log::Log4perl;
use casa_constants_for_installer;

STDOUT->autoflush(1);

use strict;

my $project_name     = $ARGV[0];
my $vcf_file_list    = $ARGV[1];
my $dump_dir         = $ARGV[2];
my $summary_file     = $ARGV[3];
my $has_annotated_vcf = $ARGV[4];

# All variants in the VCF which are larger
# than the number below will be discarded
my $max_variant_length = 255;

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



my $usage =
"$0 <project name/table name> <vcf file list> <dump dir> <has_annotated_vcf   0= HASN'T; 1=HAS>\n";

$log->logexit( $usage ) if scalar(@ARGV) != 5;

my @vcf_list_path;
my @vcf_list_path_ab;

# Reading VCF list
open VCF_LIST, "$vcf_file_list" or $log->logexit( "Unable to open file $vcf_file_list\n" );
while (<VCF_LIST>) {
	my $line = $_;
	chomp $line;
	my ( $sample_name, $vcf_path ) = split "\t", $line;
	push( @vcf_list_path, $vcf_path );
	
	
	if ( $has_annotated_vcf == 1 ){	
		my $vcf_path_ab = $vcf_path . '.annot';
		$vcf_path_ab =~ s{.*/}{};
		
		push( @vcf_list_path_ab, $vcf_path_ab );
	}
	
}
close(VCF_LIST);


open SUMMARY, ">$summary_file" or $log->fatal( "Unable to write on file $summary_file!\n" ); 

my $dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD )
  or $log->logexit(
  "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n"
  . DBI->errstr );

$log->info(  "Checking number of samples stored in \'$project_name\'...\n" );
my $num_samples_in_db = VCFDB::get_last_sample_num( $dbh, $project_name ) + 1;

for ( my $sample_num = 0 ; $sample_num < $num_samples_in_db ; $sample_num++ ) {
	$log->info( "\nQuerying sample $sample_num...\n" );


	my $snps_from_db  = $dump_dir . "/" . "snps_from_db_s" . $sample_num;
	my $subst_from_db = $dump_dir . "/" . "subst_from_db_s" . $sample_num;
	my $ins_from_db   = $dump_dir . "/" . "ins_from_db_s" . $sample_num;
	my $del_from_db   = $dump_dir . "/" . "del_from_db_s" . $sample_num;


	# Raw fields
	$log->info( "\tNum. polymorphic sites...\n" );
	my $num_pol_db =
	  VCFDB::get_num_polymorphic_sites( $dbh, $project_name, $sample_num );
	my $pol_db_str =
	  VCFDB::get_polymorphic_sites( $dbh, $project_name, $sample_num );
    write_to_file( $snps_from_db, $pol_db_str );

	  
	$log->info( "\tNum. substitutions sites...\n" );
	my $num_subst_db =
	  VCFDB::get_num_substitutions( $dbh, $project_name, $sample_num );
	my $subst_db_str =
	  VCFDB::get_substitutions( $dbh, $project_name, $sample_num );
	write_to_file( $subst_from_db, $subst_db_str );


	$log->info( "\tNum. insertions sites...\n" );
	my $num_ins_db =
	  VCFDB::get_num_insertions( $dbh, $project_name, $sample_num );
	my $ins_db_str =
	  VCFDB::get_insertions( $dbh, $project_name, $sample_num );
	write_to_file( $ins_from_db, $ins_db_str );


	$log->info( "\tNum. deletions sites...\n" );
	my $num_del_db =
	  VCFDB::get_num_deletions( $dbh, $project_name, $sample_num );
	my $del_db_str =
	  VCFDB::get_deletions( $dbh, $project_name, $sample_num );
	write_to_file( $del_from_db, $del_db_str );
	  

	my $subst_from_db_ab = $dump_dir . "/" . "subst_from_db_ab_s" . $sample_num;
	my $ins_from_db_ab = $dump_dir . "/" . "ins_from_db_ab_s" . $sample_num;
	my $del_from_db_ab = $dump_dir . "/" . "del_from_db_ab_s" . $sample_num;

	my $coding_indels_from_db_ab = $dump_dir . "/" . "coding_indels_from_db_ab_s" . $sample_num;
	my $coding_ins_from_db_ab = $dump_dir . "/" . "coding_ins_from_db_ab_s" . $sample_num;
	my $coding_del_from_db_ab = $dump_dir . "/" . "coding_del_from_db_ab_s" . $sample_num;

	my $ncoding_subst_from_db_ab = $dump_dir . "/" . "ncoding_subst_from_db_ab_s" . $sample_num;
	my $num_syn_db_from_db_ab = $dump_dir . "/" . "num_syn_db_from_db_ab_s" . $sample_num;
	my $num_nsyn_db_from_db_ab = $dump_dir . "/" . "num_nsyn_db_from_db_ab_s" . $sample_num;


	# Processed fields
	my $num_subst_db_pre =
	  VCFDB::get_num_substitutions_pre( $dbh, $project_name, $sample_num );    #
	my $subst_db_pre_str =
	  VCFDB::get_substitutions_pre( $dbh, $project_name, $sample_num );    #
	write_to_file( $subst_from_db_ab, $subst_db_pre_str );

	my $num_ins_db_pre =
	  VCFDB::get_num_insertions_pre( $dbh, $project_name, $sample_num );       #
	my $ins_db_pre_str =
	  VCFDB::get_insertions_pre( $dbh, $project_name, $sample_num );       #
	write_to_file( $ins_from_db_ab, $ins_db_pre_str );
	
	my $num_del_db_pre =
	  VCFDB::get_num_deletions_pre( $dbh, $project_name, $sample_num );        #
	my $del_db_pre_str =
	  VCFDB::get_deletions_pre( $dbh, $project_name, $sample_num );        #
	write_to_file( $del_from_db_ab, $del_db_pre_str );
	
	my $num_indels_db_pre = $num_ins_db_pre + $num_del_db_pre;

	my $coding_indels_pre =
	  VCFDB::get_num_coding_indels_pre( $dbh, $project_name, $sample_num );    #
	my $coding_indels_pre_str =
	  VCFDB::get_coding_indels_pre( $dbh, $project_name, $sample_num );    #
	write_to_file( $coding_indels_from_db_ab, $coding_indels_pre_str );
	
	my $num_coding_ins_db_pre =
	  VCFDB::get_num_coding_ins_pre( $dbh, $project_name, $sample_num );       #
	my $coding_ins_db_pre_str =
	  VCFDB::get_coding_ins_pre( $dbh, $project_name, $sample_num );       #
	write_to_file( $coding_ins_from_db_ab, $coding_ins_db_pre_str );
	
	my $num_coding_del_db_pre =
	  VCFDB::get_num_coding_del_pre( $dbh, $project_name, $sample_num );       #
	my $coding_del_db_pre_str =
	  VCFDB::get_coding_del_pre( $dbh, $project_name, $sample_num );       #
	write_to_file( $coding_del_from_db_ab, $coding_del_db_pre_str );

	# Gene structure based
	my $num_ncoding_subst_db =
	  VCFDB::get_num_ncoding_subst_pre( $dbh, $project_name, $sample_num );
	my $ncoding_subst_from_db_ab_str = VCFDB::get_ncoding_subst_pre( $dbh, $project_name, $sample_num );
	write_to_file( $ncoding_subst_from_db_ab, $ncoding_subst_from_db_ab_str );
	  
	my $num_syn_db = VCFDB::get_num_syn_pre( $dbh, $project_name, $sample_num );
	my $num_syn_db_str = VCFDB::get_syn_pre( $dbh, $project_name, $sample_num );
	write_to_file( $num_syn_db_from_db_ab, $num_syn_db_str );

	my $num_nsyn_db =
	  VCFDB::get_num_nsyn_pre( $dbh, $project_name, $sample_num );
	my $num_nsyn_db_str = VCFDB::get_nsyn_pre( $dbh, $project_name, $sample_num );
	write_to_file( $num_nsyn_db_from_db_ab, $num_nsyn_db_str );

	# Checking VCF list
	my $file = $vcf_list_path[$sample_num];
	$log->info( "Checking VCF file $file...\n" );

	# With possible duplicates: Records containing the same chrom, pos, ref and alt
	my $original_snps_from_vcf = $dump_dir . "/" . "original_snps_from_vcf_s" . $sample_num;
	my $snps_from_vcf = $dump_dir . "/" . "snps_from_vcf_s" . $sample_num;
	my $subst_from_vcf = $dump_dir . "/" . "subst_from_vcf_s" . $sample_num;
	my $ins_from_vcf = $dump_dir . "/" . "ins_from_vcf_s" . $sample_num;
	my $del_from_vcf = $dump_dir . "/" . "del_from_vcf_s" . $sample_num;

	$log->info( "\tNum. polymorphic sites reported VCF (original, possible duplicates) ...\n" );	
	my $original_num_pol_vcf =
`grep -v '^#' $file | awk ' \$5 != "." && length(\$4) <= $max_variant_length && length(\$5) <= $max_variant_length  {print \$0}' FS="\t" | sort -k1,1 -k2,2n | tee $original_snps_from_vcf | wc -l`;

	# Removed duplicated records. Records containing the same chrom, pos, ref and alt
	$log->info(  "\tNum. polymorphic sites ...\n" );	
	my $num_pol_vcf = `awk '{print \$1,\$2,\$3,\$4,\$5}' FS="\t" $original_snps_from_vcf | sort | uniq | sed 's/ /\t/g' | tee $snps_from_vcf | wc  -l`;


# At least Pilon report substitutions of more than 1 bp len in ref and alt. These are reported as long insertions
# in the field SNV of the VCF

	$log->info( "\tNum. substitutions ...\n" );
	my $num_subst_vcf =
`awk ' ( length(\$4) == length(\$5) ) || \$5 ~ "," {print \$1,\$2}' FS="\t" $snps_from_vcf |sort -k1,1 -k2,2n | tee $subst_from_vcf | wc -l`;
	#my $num_subst_vcf =
#`awk ' ( length(\$4) == length(\$5) && length(\$4) == 1 ) || \$5 ~ "," {print \$1,\$2}' FS="\t" $snps_from_vcf #|sort -k1,1 -k2,2n | tee $subst_from_vcf | wc -l`;


	$log->info( "\tNum. insertions ...\n" );
	my $num_ins_vcf =
`awk ' length(\$4) < length(\$5) && \$5 !~ "," {print \$1,\$2}' FS="\t" $snps_from_vcf | sort -k1,1 -k2,2n | tee $ins_from_vcf | wc -l`;

	$log->info( "\tNum. deletions ...\n" );
	my $num_del_vcf =
`awk ' length(\$4) > length(\$5) {print \$1,\$2}' FS="\t" $snps_from_vcf | sort -k1,1 -k2,2n | tee $del_from_vcf | wc -l`;

	chomp $num_pol_vcf;
	chomp $num_subst_vcf;
	chomp $num_ins_vcf;
	chomp $num_del_vcf;

	# Checking VCF list
	$file = $vcf_list_path_ab[$sample_num];

	my $original_num_pol_vcf_ab  = "NA";
	my $num_pol_vcf_ab           = "NA";
	my $num_syn_vcf_ab           = "NA";
	my $num_nsyn_vcf_ab          = "NA";
	my $num_ncoding_subst_vcf_ab = "NA";
	my $num_coding_del_vcf_ab    = "NA";
	my $num_coding_ins_vcf_ab    = "NA";
	my $num_coding_indels_vcf_ab = "NA";

	if ( $file ne "" ) {
		$log->info( "Checking file $file...\n" );
		
		# With possible duplicates: Records containing the same chrom, pos, ref and alt
		my $original_snps_from_vcf_ab = $dump_dir . "/" . "original_snps_from_vcf_ab_s" . $sample_num;
		my $snps_from_vcf_ab = $dump_dir . "/" . "snps_from_vcf_ab_s" . $sample_num;
		my $syn_subst_from_vcf_ab = $dump_dir . "/" . "syn_subst_from_vcf_ab_s" . $sample_num;
		my $nsyn_subst_from_vcf_ab = $dump_dir . "/" . "nsyn_subst_from_vcf_ab_s" . $sample_num;
		my $ncoding_subst_from_vcf_ab = $dump_dir . "/" . "ncoding_subst_from_vcf_ab_s" . $sample_num;
		my $coding_del_from_vcf_ab = $dump_dir . "/" . "coding_del_from_vcf_ab_s" . $sample_num;
		my $coding_ins_from_vcf_ab = $dump_dir . "/" . "coding_ins_from_vcf_ab_s" . $sample_num;


		# At least Pilon report substitutions of more than 1 bp len in ref and alt. These are reported as long insertions
		# in the field SNV of the VCF

		$log->info( "\tNum. polymorphic sites reported annotated VCF (original, possible duplicates) ...\n" );	
		my $original_num_pol_vcf_ab =
`grep -v '^#' $file | awk ' \$5 != "." && length(\$4) <= $max_variant_length && length(\$5) <= $max_variant_length  {print \$0}' FS="\t" | sort -k1,1 -k2,2n | tee $original_snps_from_vcf_ab | wc -l`;
		

		# Removed duplicated records. Records containing the same chrom, pos, ref, alt and annotation
		$log->info( "\tNum. polymorphic sites ...\n" );
		$num_pol_vcf_ab =
`cut -f1-5,11- $original_snps_from_vcf_ab | sort | uniq | tee  $snps_from_vcf_ab | wc -l`;


		$log->info( "\tNum. synonymous subst. ...\n" );
		$num_syn_vcf_ab = `grep "(SYN)" $snps_from_vcf_ab | awk '{print \$1,\$2}' | sort -k1,1 -k2,2n | tee $syn_subst_from_vcf_ab | wc -l`;

		$log->info( "\tNum. non-synonymous subst. ...\n" );
		$num_nsyn_vcf_ab = `grep "(NSY)" $snps_from_vcf_ab | awk '{print \$1,\$2}' | sort -k1,1 -k2,2n | tee $nsyn_subst_from_vcf_ab | wc -l`;

		
# At least Pilon report substitutions of more than 1 bp len in ref and alt. These are reported as long insertions
# in the field SNV of the VCF		
		$log->info( "\tNum. non-coding subst. ...\n" );
#		$num_ncoding_subst_vcf_ab =
#`awk ' length(\$4) == length(\$5) && length(\$4) == 1 {print \$0}' FS="\t" $snps_from_vcf_ab | grep "intergenic" | awk '{print \$1,\$2}' | sort -k1,1 -k2,2n | tee $ncoding_subst_from_vcf_ab | wc -l`;
		$num_ncoding_subst_vcf_ab =
`awk ' length(\$4) == length(\$5) {print \$0}' FS="\t" $snps_from_vcf_ab | grep "intergenic" | awk '{print \$1,\$2}' | sort -k1,1 -k2,2n | tee $ncoding_subst_from_vcf_ab | wc -l`;


		$log->info( "\tNum. coding deletions ...\n" );
		$num_coding_del_vcf_ab =
		  `grep ",DELETION" $snps_from_vcf_ab | awk ' length(\$4) != length(\$5) {print \$1,\$2}' | sort -k1,1 -k2,2n | tee $coding_del_from_vcf_ab | wc -l`;

		$log->info( "\tNum. coding insertions ...\n" );;
		$num_coding_ins_vcf_ab =
		  `grep ",INSERTION" $snps_from_vcf_ab | awk ' length(\$4) != length(\$5) {print \$1,\$2}' | sort -k1,1 -k2,2n | tee $coding_ins_from_vcf_ab | wc -l`;

		$num_coding_indels_vcf_ab =
		  $num_coding_del_vcf_ab + $num_coding_ins_vcf_ab;

		chomp $num_pol_vcf_ab;
		chomp $num_syn_vcf_ab;
		chomp $num_nsyn_vcf_ab;
		chomp $num_ncoding_subst_vcf_ab;
		chomp $num_coding_ins_vcf_ab;
		chomp $num_coding_del_vcf_ab;
	}

	my $num_indels_vcf = $num_ins_vcf + $num_del_vcf;
	my $num_indels_db  = $num_ins_db + $num_del_db;

	if ( 
		(
			$num_pol_db != $num_pol_vcf  ||
			$num_subst_db != $num_subst_db_pre ||
			$num_subst_db != $num_subst_vcf ||
			$num_ins_db != $num_ins_db_pre || 
			$num_ins_db != $num_ins_vcf ||
			$num_del_db != $num_del_db_pre || 
			$num_del_db != $num_del_vcf ||
			$num_indels_db != $num_indels_db_pre ||
			$num_indels_db != $num_indels_vcf 
	  	) || (
			( $vcf_list_path_ab[$sample_num] ne "" ) &&
			(
				$num_pol_db != $num_pol_vcf_ab ||
				$num_coding_ins_db_pre != $num_coding_ins_vcf_ab ||
				$num_coding_del_db_pre != $num_coding_del_vcf_ab ||
				$coding_indels_pre != $num_coding_indels_vcf_ab ||
				$num_ncoding_subst_db != $num_ncoding_subst_vcf_ab ||
				$num_syn_db != $num_syn_vcf_ab ||
				$num_nsyn_db != $num_nsyn_vcf_ab
			)
		)
	  ) {

		print SUMMARY "\n>>>> ERROR: sample $sample_num\n";
	  }else{
		print SUMMARY ">>>> OK: sample $sample_num\n";
	  }
	  	  

		  print SUMMARY "\t\t\t\tDB_raw\tDB_processed\tVCF\n";
		  print SUMMARY
"Num. polymorphic sites:\t$num_pol_db\tNA\t$num_pol_vcf AB:$num_pol_vcf_ab\n"
		  ;    #

		  print SUMMARY
"Num. substitutions:\t$num_subst_db\t$num_subst_db_pre\t$num_subst_vcf\n"
		  ;    #
		  print SUMMARY
		  "Num. insertions:\t$num_ins_db\t$num_ins_db_pre\t$num_ins_vcf\n";    #
		  print SUMMARY
		  "Num. deletions:\t$num_del_db\t$num_del_db_pre\t$num_del_vcf\n";     #

		  print SUMMARY
"Num. coding insertions:\tNA\t$num_coding_ins_db_pre\tNA AB:$num_coding_ins_vcf_ab\n"
		  ;                                                                    #
		  print SUMMARY
"Num. coding deletions:\tNA\t$num_coding_del_db_pre\tNA AB:$num_coding_del_vcf_ab\n"
		  ;                                                                    #

		  print SUMMARY
"Num. coding indels:\tNA\t$coding_indels_pre\tNA AB:$num_coding_indels_vcf_ab\n"
		  ;                                                                    #
		  print SUMMARY
		  "Num. indels:\t$num_indels_db\t$num_indels_db_pre\t$num_indels_vcf\n"
		  ;                                                                    #

		  print SUMMARY
"Num. non-coding substitutions:\tNA\t$num_ncoding_subst_db\tNA AB:$num_ncoding_subst_vcf_ab\n";
		  print SUMMARY "Num. syn:\tNA\t$num_syn_db\tNA AB:$num_syn_vcf_ab\n";
		  print SUMMARY "Num. nsyn:\tNA\t$num_nsyn_db\tNA AB:$num_nsyn_vcf_ab\n";

}

close(SUMMARY);

exit(0);


sub write_to_file{
	my ($file_name, $str ) = @_ ;
	
	open OUT, ">$file_name" or $log->logexit( "\nUnable to open file $file_name!!\n" );
	print OUT $str;
	close(OUT);
}

