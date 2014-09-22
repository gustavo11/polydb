#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin";

use lib $ENV{vcf_pm_dir};
use lib $ENV{cgibin_root};


use DBI;
use Vcf;
use VCFDB;
use VCFDB_OFFLINE;
use VCFUtils;
use Data::Dumper;
use Carp;
use strict;
use IO::Handle;
use casa_constants_for_installer;
use Log::Log4perl;
use Term::ProgressBar;
use FileSeries;

use strict;

STDOUT->autoflush(1);

my $debug  = 0;
my $online = 0;
my $newdb  = 1;
my $READ_ONLY_FIRST_VCF_HEADER = 0;


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

my $usage = "vcf2sql.pl <1 = keep invariant sites;0 = disregard those> <vcf file list> <project name>";



$log->logexit( $usage ) if ( scalar(@ARGV) != 3 );

my $keep_invariant_sites   = $ARGV[0];
my $vcf_file_list 	   	   = $ARGV[1];
my $project_name           = $ARGV[2];

my $dbh;

my $num_samples_in_db = 0;



if ( not $newdb ) {
	#connects to databse
	$dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD )
	  or $log->logexit( "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n"
	  . DBI->errstr );
	$num_samples_in_db = VCFDB::get_last_sample_num( $dbh, $project_name ) + 1;
}

##############################################################
# Read VCF LIST

my @vcf_list;
my @sample_names;
my @vcf_num_calls;
my %sample_id;

my @vcf_list;

my ( $refSampleNames, $refVCFList, $refNumCalls, $refSampleId )  = VCFUtils::read_vcf_list( $vcf_file_list, $log );
@vcf_list 	= @{$refVCFList};
@sample_names 	= @{$refSampleNames};
@vcf_num_calls	= @{$refNumCalls};
%sample_id 	= %{$refSampleId};

##############################################################




my %fields;

# Map field names to field id
my %name2id;

my @info_fields;
my @filter_fields;
my @format_fields;


# Parsing HEADERs
my $cont = 0;
foreach my $vcf_file (@vcf_list) {
	$log->info("Parsing header of file $vcf_file" );
	
	next if $cont == 1 && $READ_ONLY_FIRST_VCF_HEADER == 1;
	$cont = 1;

	my $vcf = Vcf->new( file => $vcf_file );
	$vcf->parse_header();

	foreach my $field_category ( ( 'INFO', 'FILTER', 'FORMAT' ) ) {
		my @headers = $vcf->get_header_line( key => $field_category );

		foreach my $items_arr_ref (@headers) {

			#print Data::Dumper->Dump([$items_arr_ref]);
			#getc();
			foreach my $items_hash_ref ( @{$items_arr_ref} ) {

				#print ">>" . Data::Dumper->Dump([$items_hash_ref]);
				#getc();
				foreach my $field ( values %{$items_hash_ref} ) {
					if ($debug) {
						print "Field type: $field_category"
						  . "  Key: "
						  . $field->{ID}
						  . "  Type: "
						  . $field->{Type}
						  . "  Number of fields: "
						  . $field->{Number}
						  . "  Description: "
						  . $field->{Description} . "\n";
					}

					my $id               = $field->{ID} . "_" . $field_category;
					my $name             = $field->{ID};
					my $type             = $field->{Type};
					my $number_subfields = $field->{Number};
					my $desc             = $field->{Description};

					if ( $field_category eq "FILTER" ) {
						$type             = "Boolean";
						$number_subfields = 1;
					}elsif( $field_category eq "INFO" && $type eq "Flag" ){
						$number_subfields = 1;						
					}
					elsif ( $field_category eq "INFO" ) {
						if (   $number_subfields eq "."
							|| $number_subfields > 1
							|| $number_subfields == -1 )
						{
							$type             = "String";
							$number_subfields = 1;

							# IF number of subfields is not a number than raise an error
						}
						elsif ( $number_subfields =~ /\D/ ) {
							$type             = "String";
							$number_subfields = 1;

							$log->warn( 							
							  "Value of entry \'Number\' on field \'$name\' "
							  . "should be either a number or \'.\' for fields with "
							  . "variable number of subfields\n" );
						}

					}
					elsif ( $field_category eq "FORMAT" ) {

						# TODO: Not dealing with subfields yet.
						# For the timebeing, fields containing subfields will be treated as
						# strings

						if (   $number_subfields eq "."
							|| $number_subfields > 1
							|| $number_subfields == -1 )
						{
							$type             = "String";
							$number_subfields = 1;

							# IF number of subfields is not a number than raise an error
						}
						elsif ( $number_subfields =~ /\D/ ) {
							$type             = "String";
							$number_subfields = 1;

							$log->warn( "Value of entry \'Number\' on field \'$name\' "
							  . "should be either a number or \'.\' for fields with "
							  . "variable number of subfields\n" );

						}
					}

			# Checking if the field was already added to %fields hash
			# if so ... skip it. But before that check if the type and number of subfields match ...
					if ( defined( $fields{$id}{id} ) ){
						  if ( $number_subfields != $fields{$id}{number_subfields}
							|| $type != $fields{$id}{type} ){
						  	$log->logexit(  
						  		"Field \'$name\' was already declared with a different definition"
						  		. " (different type or different #subfields) on either current"
						  		. " or previously parsed VCF file.\n" );
						  	}
						  next;
					  }

					  if ( $field_category eq "FILTER" ) {
						push( @filter_fields, $id );
					}
					elsif ( $field_category eq "INFO" ) {
						push( @info_fields, $id );
					}
					elsif ( $field_category eq "FORMAT" ) {
						push( @format_fields, $id );
					}

					$name2id{$name}{$field_category} = $id;

					$fields{$id}{id}               = $id;
					$fields{$id}{name}             = $name;
					$fields{$id}{desc}             = $desc;
					$fields{$id}{field_category}   = $field_category;
					$fields{$id}{type}             = $type;
					$fields{$id}{number_subfields} = $number_subfields;
					$fields{$id}{desc}             = $desc;

					if ($debug) {
						print "After parsing... Category: "
						  . $fields{$id}{field_category}
						  . "  Key: "
						  . $fields{$id}{name}
						  . "  Type: "
						  . $fields{$id}{type}
						  . "  Number of fields: "
						  . $fields{$id}{number_subfields}
						  . "  Description: "
						  . $fields{$id}{desc} . "\n";
						getc();
					}

				}
			}
		}
	}

	$vcf->close();
}

# Add a field that was found in the VCF content
# but not listed in the header
$fields{LowQual_FILTER}{name} = "LowQual";
$fields{LowQual_FILTER}{type} = "Boolean";
$fields{LowQual_FILTER}{desc} = "Low quality SNP call according to the genotype caller application.";
$fields{LowQual_FILTER}{number_subfields} = 1;
$fields{LowQual_FILTER}{field_category}   = "FILTER";
$fields{LowQual_FILTER}{id}               = "LowQual_FILTER";
$name2id{LowQual}{FILTER} = "LowQual_FILTER";
push( @filter_fields, "LowQual_FILTER" );

# Add fixed fields
$fields{chrom}{name}             = "chrom";
$fields{chrom}{type}             = "String";
$fields{chrom}{number_subfields} = 1;
$fields{chrom}{field_category}   = "FIXED";
$fields{chrom}{id}               = "chrom";
$fields{chrom}{reference_based}  = 1;

$fields{position}{name}             = "position";
$fields{position}{type}             = "Integer";
$fields{position}{number_subfields} = 1;
$fields{position}{field_category}   = "FIXED";
$fields{position}{id}               = "position";
$fields{position}{reference_based}  = 1;


$fields{id}{name}             = "id";
$fields{id}{type}             = "String";
$fields{id}{number_subfields} = 1;
$fields{id}{field_category}   = "FIXED";
$fields{id}{id}               = "id";
$fields{id}{reference_based}  = 1;


$fields{reference}{name}             = "reference";
$fields{reference}{type}             = "String";
$fields{reference}{number_subfields} = 1;
$fields{reference}{field_category}   = "FIXED";
$fields{reference}{id}               = "reference";
$fields{reference}{reference_based}  = 1;


$fields{alt}{name}             = "alt";
$fields{alt}{type}             = "String";
$fields{alt}{number_subfields} = 1;
$fields{alt}{field_category}   = "FIXED";
$fields{alt}{id}               = "alt";
$fields{alt}{reference_based}  = 0;

$fields{qual}{name}             = "qual";
$fields{qual}{type}             = "Float";
$fields{qual}{number_subfields} = 1;
$fields{qual}{field_category}   = "FIXED";
$fields{qual}{id}               = "qual";
$fields{qual}{reference_based}  = 0;

# Add processed fields
$fields{gene}{name}             = "gene";
$fields{gene}{type}             = "String";
$fields{gene}{number_subfields} = 1;
$fields{gene}{id}               = "gene";
$fields{gene}{reference_based}  = 1;

$fields{gene_annotation}{name}             = "gene_annotation";
$fields{gene_annotation}{type}             = "Text";
$fields{gene_annotation}{number_subfields} = 1;
$fields{gene_annotation}{id}               = "gene_annotation";
$fields{gene_annotation}{reference_based}  = 1;

$fields{var_type}{name}             = "var_type";
$fields{var_type}{type}             = "String";
$fields{var_type}{number_subfields} = 1;
$fields{var_type}{id}               = "var_type";
$fields{var_type}{reference_based}  = 1;

$fields{var_length}{name}             = "var_length";
$fields{var_length}{type}             = "Integer";
$fields{var_length}{number_subfields} = 1;
$fields{var_length}{id}               = "var_length";
$fields{var_length}{reference_based}  = 0;

$fields{var_syn_nsyn}{name}             = "var_syn_nsyn";
$fields{var_syn_nsyn}{type}             = "String";
$fields{var_syn_nsyn}{number_subfields} = 1;
$fields{var_syn_nsyn}{id}               = "var_syn_nsyn";
$fields{var_syn_nsyn}{reference_based}  = 0;

# This field will be placed in a separate table (full_annot table)
$fields{full_annot}{name}             = "full_annot";
$fields{full_annot}{type}             = "Text";
$fields{full_annot}{number_subfields} = 1;
$fields{full_annot}{id}               = "full_annot";
$fields{full_annot}{reference_based}  = 0;


$log->info( "Done parsing header ...\n" );
$log->debug( "Number of fields:" . scalar( @vcf_list ) * scalar( keys( %fields ) ) . "\n" );

if ($newdb) {
	$log->info( "Generating create table command ...\n" ) ;
	
	my ( $data_table_sql, $ref_based_indexes_sql, $sample_based_indexes_sql, 
	     $full_annot_sql, $full_annot_alter_table_sql, $full_annot_ref_based_indexes_sql, 
	     $vcf_field_table_sql ) =
	  VCFDB_OFFLINE::postgres_generate_joined_table_schema_populate_vcf_fields_table( \%fields,
		\@vcf_list, $project_name );

	if( $debug ){
	   print "\n\n";
	   print "CREATE TABLE\n";
	   print "============\n";
	   print "$data_table_sql\n\n";
	   print "$vcf_field_table_sql";
	   print "\n\n";
	}

	# Generates file that create tables	
	open SQL_OUT, ">" . $project_name . "_create_tables.sql";
	print SQL_OUT "$data_table_sql\n";
	close(SQL_OUT);

    # Generates file that create ref based indexes
	open SQL_OUT, ">" . $project_name . "_ref_based_indexes.sql";
	print SQL_OUT "$ref_based_indexes_sql\n";
	close(SQL_OUT);
		
    # Generates file that create sample based indexes
	open SQL_OUT, ">" . $project_name . "_sample_based_indexes.sql";
	print SQL_OUT "$sample_based_indexes_sql\n";
	close(SQL_OUT);	

	# Generates file that create table full_annot, the content of Brians script	
	open SQL_OUT, ">" . $project_name . "_create_tables.full_annot.sql";
	print SQL_OUT "$full_annot_sql\n";
	close(SQL_OUT);

    # Generates file that alter full_annot table and create ref based indexes
	open SQL_OUT, ">" . $project_name . "_alter_table.full_annot.sql";
	print SQL_OUT "$full_annot_alter_table_sql\n$full_annot_ref_based_indexes_sql\n";
	close(SQL_OUT);	

	
	VCFDB::upload_into_db( $dbh, $data_table_sql ) if $online and $newdb;
	$log->info( "Done generating create table commands ...\n" ) ;	
}
else {
	$log->info( "Altering table ...\n" ) ;
	my ($last_sample_num) = VCFDB::get_last_sample_num( $dbh, $project_name );
	my $sample_num = $last_sample_num + 1;
	my ($alter_table_sql) =
	  VCFDB_OFFLINE::postgres_generate_alter_table( $sample_num, \%fields, \@vcf_list,
		$project_name );
	VCFDB::upload_into_db( $dbh, $alter_table_sql ) if $online;

	print "Writing to file alter table command ...\n";
	open SQL_OUT, ">" . $project_name . "_create_tables.sql";
	print SQL_OUT "$alter_table_sql\n";
	close(SQL_OUT);
	$log->info( "Done altering table ...\n" ) ;
}



######################################
# Inserting samples into sample table

# open SQL_INSERT_OUT, ">" . $project_name . "_insert_sample_table.sql";

# my $start_sample_num = 0;
# $start_sample_num = VCFDB::get_last_sample_num( $dbh, $project_name ) + 1 if not $newdb;


# my $sql =
#  VCFDB_OFFLINE::generate_sample_table_inserts( $project_name, \@sample_names, $start_sample_num );

# BEGIN and COMMIT turns off autocommit
# print SQL_INSERT_OUT $sql;

# close(INSERT_OUT);

################################
# Generating data rows (inserts)


# Those two objects manages the creation of a series of files
# of 1 million lines each containing SQL update and insert commands
my $sql_insert_out = 
	FileSeries::new( '.', $project_name . "_inserts", 'sql', 1000000, "BEGIN;\n", "COMMIT;\n" );

my $sql_update_out = 
	FileSeries::new( '.', $project_name . "_updates", 'sql', 1000000, "BEGIN;\n", "COMMIT;\n" );
	
$sql_insert_out->open();
$sql_update_out->open();

# Read polymorphic sites file
#my %sites;
#if ( $keep_invariant_sites == 0 )
#	\%sites = VCFUtils::read_pol_sites( $project_name );
#}


my %inserted_rows;
my $vcf_file_num = 1;
foreach my $vcf_file (@vcf_list) {
	my $vcf = Vcf->new( file => $vcf_file );
	$vcf->parse_header();

	
	$log->info( "Reading data from $vcf_file (Generating INSERT and UPDATE SQL commands) [File num.: $vcf_file_num] ...\n" );
	
	my $progress_eta = $vcf_num_calls[ $vcf_file_num - 1 ];
	# Only using progress bar if the number of insert and/or update lines
	# is higher than 100k
	my $progress;
	if( $progress_eta >= 100000 ){
		$progress = Term::ProgressBar->new( { count => $progress_eta, remove => 1 });
	}
	
	
	my $cont_line = 0;

	my $num_insert_rows = 0;
	while ( my $line = $vcf->next_line ) {
		my %data;
		chomp $line;
		my @items = split( /\t/, $line );
		$cont_line++;

		####################
		# Get basic fields: chrom, pos, id, ref, alt...
		$data{chrom}     = $items[0];
		$data{position}  = $items[1];
		$data{id}        = $items[2];
		$data{reference} = $items[3];
		$data{alt}       = $items[4];
		$data{alt}       = $items[3] if $items[4] eq ".";				

		$data{qual} = $items[5];
		$data{qual} = 0 if $items[5] eq ".";

		#Progress indicator
		if ( $cont_line % 1000000 == 0 ) {
			my $m = $cont_line / 1000000;
			$log->debug( "$m M calls processed ...\n" );
		}
		$progress->update( $cont_line ) 
			 if( defined $progress && $cont_line % 10000 == 0 );				
		
		# Discard if either reference or alternative genotype greater than 255 bp
		if ( length( $data{alt} ) > 255 || length( $data{reference} ) > 255 ){
			#if( length( $data{alt} > length( $data{reference} ) )
			next;
		}
		
		# Discard if inavriant site
#		next if( $keep_invariant_sites == 0 &&
# not defined $sites{$data{chrom}}{$data{position}} );

		# Adding processed fields: variance type (var_type) and variance length (var_length)
		my $raw_var_length = length( $data{alt} ) - length( $data{reference} );
		my $has_alleles  = ( $data{alt} =~ "," ); 
		#print $data{alt} . "  " . $data{reference} . "\n";
		
		# if NO variation or substitution
		# than the var_type is equal SUBSTITUTION
		$data{var_type} = "SUBSTITUTION";
		
		if ( $raw_var_length == 0 || $has_alleles ) {
			$data{var_type} = "SUBSTITUTION";
		}
		elsif ( $raw_var_length < 0 ) {
			$data{var_type} = "DELETION";
		}
		elsif ( $raw_var_length > 0 ) {
			$data{var_type} = "INSERTION";
		}
		$data{var_length} = abs($raw_var_length);

		#############################
		# Creating inserts
		#############################

		my $previously_defined =
		  defined( $inserted_rows{ $data{chrom} }{ $data{position} }{ $data{reference} }
			  { $data{var_type} } );
		my @reference_previous_values_arr =
		  keys( %{ $inserted_rows{ $data{chrom} }{ $data{position} } } );

		# if not a new database
		if ( not $newdb ) {

			# If still not defined try to retrieve it from the database
			if ( not defined $previously_defined ) {
				$previously_defined =
				  VCFDB::is_reference_defined( $dbh, $project_name, $data{chrom}, $data{position},
					$data{reference}, $data{var_type} );
			}

			my @previous_values_db =
			  VCFDB::get_reference_values( $dbh, $project_name, $data{chrom}, $data{position} );
			push( @reference_previous_values_arr, @previous_values_db );

		}
		
		# Checking the possibility of distinct reference sequences
		if ( not $previously_defined ) {

			# The reference genotype in the same position should be at least
			# similar between two different VCF files
			foreach my $ref_previous_value (@reference_previous_values_arr) {
				if (   ( not $ref_previous_value =~ /$data{reference}/ )
					&& ( not $data{reference} =~ /$ref_previous_value/ ) )
				{

					die "Reference genotype on \'$vcf_file\' chrom: "
					  . $data{chrom}
					  . " position: "
					  . $data{position}
					  . " genotype: \'"
					  . $data{alt}
					  . "\' differs from reference genotype on other VCF files and Database \'"
					  . $ref_previous_value . "\'\n"

				}
			}

#print "Current: " . $data{alt} . " Reference: $ref_previous_value      Was previously defined: $was_previously_defined\n";

			# Add insert if the current position not added yet OR
			# if it contains a slightly different reference: maybe a deletion is being reported
			# and substitution was processed earlier

			my $data_sql = VCFDB_OFFLINE::insert_into_table_data( \%fields, $project_name, \%data, scalar( @sample_names ) );

			$sql_insert_out->print( $data_sql );			
			
			if( $debug ){
				print STDERR "INSERT: $data_sql\n";
				getc();
			}			

#print $sql_insert_out $data_sql if (  ( scalar( @reference_previous_values ) != 0 ) || ( length( $data{alt} ) > 1 )  );

			VCFDB::upload_into_db( $dbh, $data_sql, $cont_line, $line ) if $online;

			$num_insert_rows++;
			$inserted_rows{ $data{chrom} }{ $data{position} }{ $data{reference} }
			  { $data{var_type} } = 1;
		}
				

		#############################
		# Creating updates
		#############################
		

		####################
		# Get FILTER field
		my $filter_column = $items[6];
		my @filter_items = split ";", $filter_column;

		# Initially adjusted as the call had passed all filters
		foreach my $curr_id (@filter_fields) {
			$data{$curr_id} = "false";
		}

		# If filter column different of PASS and ".", means that call failed in at least one filter
		if ( $filter_items[0] ne "PASS" && $filter_items[0] ne ".") {
			foreach my $curr_filter_name (@filter_items) {
				my $id = $name2id{$curr_filter_name}{"FILTER"};
				
				die "name2id hash does not have an entry for filter \'$curr_filter_name\'.\nLine:\n $line\n"
				  if ( not defined $id );
				
				die "Filter \'$curr_filter_name\' not defined in the header of file.\nLine:\n $line\n"
				  if ( ( not defined $fields{$id} )
					|| ( $fields{$id}{field_category} ne "FILTER" ) );
				
				if ($debug) {
					print "FILTER Field id: " . $id . "\n";
					print "FORMAT Field value: true\n";
					getc();
				}				

				$data{$id} = "true";
			}
		}

		####################
		# Get FORMATs field
		#		foreach my $curr_id (@format_fields) {
		#			next if ( $items[8] eq "" || ( not defined ( $items[8] ) ) );
		#			my $idx = $vcf->get_tag_index( $items[8], $curr_id, ':' );
		#			next if not defined( $idx );
		#			my $value = $vcf->get_field( $items[9], $idx ) unless $idx == -1;
		#			$data{$curr_id} = $value;
		#		}

		if ( $items[8] ne "" && $items[8] ne "." ) {
			my @format_names  = split ":", $items[8];
			my @format_values = split ":", $items[9];
			for ( my $ind = 0 ; $ind < scalar(@format_names) ; $ind++ ) {

				my $id = $name2id{ $format_names[$ind] }{"FORMAT"};
				next if not defined( $id );
				
				if ($debug) {
					print "FORMAT Field id: " . $id . "\n";
					print "FORMAT Field name: " . $format_names[$ind] . "\n";
					print "FORMAT Field value: " . $format_values[$ind] . "\n";
					getc();
				}
				

				$data{$id} = $format_values[$ind];
			}
		}

		###################
		# Get INFO field
		
		# Initially adjust all INFO fields of the type Boolean to 'false'
		foreach my $curr_id (@info_fields) {
			$data{$curr_id} = "false" 
			 if( $fields{$curr_id}{type} eq "Boolean" || $fields{$curr_id}{type} eq "Flag" );
		}

		if ( $items[7] ne "" && $items[7] ne "." ) {
			my @info = split ";", $items[7];
			for ( my $ind = 0 ; $ind < scalar(@info) ; $ind++ ) {
				my ( $info_name, $info_value ) = split "=", $info[$ind];


				my $id = $name2id{$info_name}{"INFO"};
				next if not defined( $id );

				# Checking if the INFO fields is a Boolean (equivalent to VCF's 'Flag' type)
				if( $fields{$id}{type} eq "Boolean" || $fields{$id}{type} eq "Flag" ){
					$info_value = "true";
				}

				if ($debug) {
					print "INFO Field id: " . $id . "\n";					
					print "INFO Field name: " . $info_name . "\n";
					print "INFO Field value: " . $info_value . "\n";
					getc();
				}
				
				$data{$id} = $info_value;
			}
		}
		


		#print "Poor: " . $data{PoorMapping} . "\n";
		#getc();
		my $curr_sample_num = $sample_id{$vcf_file} + $num_samples_in_db;
		
		# If data contains "," means that multiple alleles were reported
		# In this case the database should store them in the alphabetic order
		# to make them consistent and prevent thing like this: C,T != T,C
		$data{alt} = VCFUtils::alpha_order_alleles( $data{alt} ) if $data{alt} =~ ",";
		
		my $data_sql =
		  VCFDB_OFFLINE::update_table_data( \%fields, $project_name, $curr_sample_num, \%data );

		  
		#print $line . "\n";
		#print $data_sql;

#print SQL_UPDATE_OUT $data_sql if (  ( scalar( @reference_previous_values ) > 1 ) || ( length( $data{alt} ) > 1 )  );
		$sql_update_out->print( $data_sql );
		
		if( $debug ){
			print STDERR "UPDATE: $data_sql\n";
			getc();
		}

		VCFDB::upload_into_db( $dbh, $data_sql, $cont_line, $line ) if $online;

		#getc();

		#print "AC $ac GT $gt\n";
		#getc();
	}
	
	
	
	# Progress indicator
	$progress->update( $progress_eta ) if( defined $progress );
	
	
	$log->debug( "\nDONE reading $vcf_file.\n" );
	$log->debug( "Insert rows added: $num_insert_rows\n" );
	$log->debug( "Updated rows added: $cont_line\n" );

	#getc();

	$vcf->close();
	$vcf_file_num++;
}

$sql_insert_out->close();
$sql_update_out->close();


if ( $online || not $newdb ) {
	$dbh->disconnect();
}

exit(0);

