#!/usr/bin/env perl

use FindBin;
use lib "$FindBin::Bin";

use lib $ENV{vcf_pm_dir};
use lib $ENV{cgibin_root};

use DBI;
use Vcf;
use VCFDB;
use Data::Dumper;
use strict;
use IPCHelper;
use IO::Handle;
use Carp;
use casa_constants_for_installer;
use Log::Log4perl;

use strict;


my $debug = 1;

if( $debug == 1 ){
	$Carp::Verbose = 1;
}


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

my $usage = "\nvcf2query.pl <vcf file list> <project name> <use genomeview 0|1> <use jbrowse 0|1> <generate boxplot 0|1> \n" .
            " <add column with full annotation when dumping 0|1 > <full path to R executable> \n\n";

die $usage if ( scalar(@ARGV) != 7 );

my $vcf_file_list 		= $ARGV[0];
my $project_name  		= $ARGV[1];
my $genomeview   		= $ARGV[2];
my $jbrowse	   			= $ARGV[3];
my $boxplot 	      	= $ARGV[4];
my $dump_full_annot 	= $ARGV[5];
my $R_exe				= $ARGV[6];


# Connect to DB
my $dbh;

$dbh = DBI->connect($CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD) or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n" . DBI->errstr;  		


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


# Header will be based on the first file
my $vcf = Vcf->new( file => $vcf_list[0] );
$vcf->parse_header();

my %fields;

my @info_fields;
my @filter_fields;
my @format_fields;

# VCF specification
# From http://www.1000genomes.org/node/101
#Possible Types for INFO fields are: Integer, Float, Flag, Character, and String.
#The Number entry is an Integer that describes the number of values that can be included with the
#INFO field. For example, if the INFO field contains a single number, then this value should be 1.
#However, if the INFO field describes a pair of numbers, then this value should be 2 and so on.
#If the number of possible values varies, is unknown, or is unbounded, then this value should be '.'.
#Possible Types are: Integer, Float, Character, String and Flag. The 'Flag' type indicates that the
#INFO field does not contain a Value entry, and hence the Number should be 0 in this case.
#The Description value must be surrounded by double-quotes.

my %FIELD_TYPE_TRANSLATION = (
	'Boolean'   => "BOOL",
	'Integer'   => "INTEGER",
	'Float'     => "FLOAT",
	'Flag'      => "BOOL",
	'Character' => "varchar(1)",
	'String'    => "varchar(255)"
);

foreach my $field_category ( ( 'INFO', 'FILTER', 'FORMAT' ) ) {
	my @headers = $vcf->get_header_line( key => $field_category );

	foreach my $items_arr_ref (@headers) {

		#print Data::Dumper->Dump([$items_arr_ref]);
		#getc();
		foreach my $items_hash_ref ( @{$items_arr_ref} ) {

			#print ">>" . Data::Dumper->Dump([$items_hash_ref]);
			#getc();
			foreach my $field ( values %{$items_hash_ref} ) {

				#print "Field type: $field_category"
				#  . "  Key: "
				#  . $field->{ID}
				#  . "  Type: "
				#  . $field->{Type}
				#  . "  Description: "
				#  . $field->{Description} . "\n";

				my $id               = $field->{ID};
				my $type             = $field->{Type};
				my $number_subfields = $field->{Number};
				my $desc             = $field->{Description};

				$fields{$id}{id}             = $id . "_" . $field_category;
				$fields{$id}{name}           = $id;
				$fields{$id}{desc}           = $desc;
				$fields{$id}{field_category} = $field_category;

				if ( $field_category eq "FILTER" ) {
					$fields{$id}{type}             = "Boolean";
					$fields{$id}{number_subfields} = 1;
					push( @filter_fields, $id );
				}
				elsif ( $field_category eq "INFO" ) {
					$fields{$id}{type}             = $type;
					$fields{$id}{number_subfields} = 1;

					if (   $number_subfields eq "."
						|| $number_subfields > 1
						|| $number_subfields == -1 )
					{
						$fields{$id}{type}             = "String";
						$fields{$id}{number_subfields} = 1;

						# IF number of subfields is not a number than raise an error
					}
					elsif ( $number_subfields =~ /\D/ ) {

carp "\nWarning: Header of file \'" . $vcf_list[0] . "\' !\n" .
 "Value of entry \'Number\' on field \'$id\' should be either a number or \'.\' for fields with variable number of subfields\n";
						$fields{$id}{type}             = "String";
						$fields{$id}{number_subfields} = 1;

					}

					push( @info_fields, $id );
				}
				elsif ( $field_category eq "FORMAT" ) {

					# TODO: Not dealing with subfields yet.
					# For the timebeing, fields containing subfields will be treated as
					# strings

					$fields{$id}{type}             = $type;
					$fields{$id}{number_subfields} = $number_subfields;

					if (   $number_subfields eq "."
						|| $number_subfields > 1
						|| $number_subfields == -1 )
					{
						$fields{$id}{type}             = "String";
						$fields{$id}{number_subfields} = 1;
					
						# IF number of subfields is not a number than raise an error
					}
					elsif ( $number_subfields =~ /\D/ ) {

carp "\nWarning: Header of file \'" . $vcf_list[0] . "\' !\n" .
 "Value of entry \'Number\' on field \'$id\' should be either a number or \'.\' for fields with variable number of subfields\n";

						if ( $id eq "PL" ) {
							$fields{$id}{type}             = "String";
							$fields{$id}{number_subfields} = 1;
						}
						else {
							$fields{$id}{type}             = $type;
							$fields{$id}{number_subfields} = 1;
						}
					}

					push( @format_fields, $id );
				}

			}
		}
	}
}

$vcf->close();

# Add a field that was found in the VCF content
# but not listed in the header
$fields{LowQual}{id}               = "LowQual_FILTER";
$fields{LowQual}{name}             = "LowQual";
$fields{LowQual}{type}             = "Boolean";
$fields{LowQual}{desc}             = "Below a quality value threshold";
$fields{LowQual}{number_subfields} = 1;  
$fields{LowQual}{field_category}   = "FILTER";
push( @filter_fields, $fields{LowQual}{name} );

my ($query_html ) = generate_query_html( \%fields, \@sample_names, $project_name, \@filter_fields );

# $dump_file_header contains the header of the dump file, file generated when user clicks download in the web front-end
my ($results_html, $dump_file_header) =
  generate_results_html( \%fields, \@sample_names, $project_name, \@filter_fields, $genomeview, $jbrowse );

open HTML_OUT, ">" . $project_name . "_query_database";
print HTML_OUT $query_html;
close(HTML_OUT);

open HTML_OUT, ">" . $project_name . "_query_results";
print HTML_OUT $results_html;
close(HTML_OUT);

# Add fixed fields
$fields{qual}{id}               = "qual";
$fields{qual}{name}             = "qual";
$fields{qual}{type}             = "Float";
$fields{qual}{number_subfields} = 1;
$fields{qual}{field_category}   = "FIXED";

my ($code) = generate_back_end_code( \%fields, \@sample_names, $project_name, \@filter_fields, $dump_file_header );

open CODE_OUT, ">" . $project_name . "_back_end.pm";
print CODE_OUT $code;
close(CODE_OUT);

$dbh->disconnect();

exit(0);

sub generate_query_html {
	my ( $ref_fields_hash, $sample_list_arr_ref, $project_name, $filters_arr_ref ) = @_;
	
	my $qual_sample_check_box = generate_sample_check_boxes( $sample_list_arr_ref, 'qual', 
															 'Float', 'qual' );
															 
	my $sample_names_table = generate_sample_names_table($sample_list_arr_ref);
	
	my @chrom_names = VCFDB::get_chrom_names( $dbh, $project_name );

	my $html_out = <<HTML;
  <!-- GENOMIC REGION -->
  <span style="font-family: Arial,Helvetica,sans-serif;"><b>Select all SNPs located on:</b></span><BR>
  <span style="font-family: Arial,Helvetica,sans-serif;">Chromosome</span>
  <select name="chrom" onchange='OnChromChange(this.form.chrom);'>
  <option value="all">all</option>
HTML
	foreach my $currChrom ( @chrom_names ){
    	$html_out .= "<option value=\"$currChrom\">$currChrom</option>\n";
	}

    $html_out .= <<HTML;
  </select>
  <BR><BR>
  <span style="font-family: Arial,Helvetica,sans-serif;">Coordinates:</span><BR> 
  <span style="font-family: Arial,Helvetica,sans-serif;">from</span>
  <input name="chrom_coord_start" type="number">
  <span style="font-family: Arial,Helvetica,sans-serif;">to</span>
  <input name="chrom_coord_end" type="number">
  <BR>
  <BR>
  
  <BR>
  <span style="font-family: Arial,Helvetica,sans-serif;">Gene locus id (e.g. $CASA::EXAMPLE_LOCUS_ID):</span><BR> 
  <small>Enclose in single quotes for exact matches (e.g. '$CASA::EXAMPLE_LOCUS_ID')</small> <BR>  
  <input name="gene">
  <BR>

  <BR>
  <span style="font-family: Arial,Helvetica,sans-serif;">Gene functional annotation (e.g. $CASA::EXAMPLE_FUNC_ANNOT):</span><BR> 
  <input name="gene_annotation">
  <BR>
 
  <BR>
  <span style="font-family: Arial,Helvetica,sans-serif;">Variance type:</span><BR> 
	<input type="radio" name="var_type" value="disregard" checked="yes"/> Disregard<br/>  	
	<input type="radio" name="var_type" value="SUBSTITUTION"/> Substitution<br/>  		
	<input type="radio" name="var_type" value="INSERTION" /> Insertion<br/>
	<input type="radio" name="var_type" value="DELETION" /> Deletion<br/>  
  <BR>  

  <BR>
  <span style="font-family: Arial,Helvetica,sans-serif;">Substitution type:</span><BR> 
	<input type="radio" name="var_syn_nsyn" value="disregard" checked="yes"/> Disregard<br/>
	<input type="radio" name="var_syn_nsyn" value="SYN" /> Synonymous<br/>  	
	<input type="radio" name="var_syn_nsyn" value="NSY" /> Non-synonymous<br/>
	<input type="radio" name="var_syn_nsyn" value="NON" /> Premature STOP codon <br/>  
	<input type="radio" name="var_syn_nsyn" value="RTH" /> Readthrough. Disrupted STOP codon <br/>  
  <BR>  
  
  
  <!-- Number of samples different than reference -->
  <span style="font-family: Arial,Helvetica,sans-serif;">Return positions with the following number of samples different than the reference genotype:</span><BR>

  <select name="operator_one_diff_reference">
    <option value="equals_to"> = </option>
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_one_diff_reference" type="number">
  AND
  <select name="operator_two_diff_reference">
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_two_diff_reference" type="number">
 <BR>
 <BR>
 <BR>
  
  
  
<!-- Genotype equations-->
  <span style="font-family: Arial,Helvetica,sans-serif;"><b>Genotype equations</b></span><BR>
  
  <span style="font-family: Arial,Helvetica,sans-serif;">
  Example 1: <b>ref = s1</b></span> <BR>
  Reference genotype EQUALS to sample 1.<BR><BR>
  
  <span style="font-family: Arial,Helvetica,sans-serif;">
  Example 2: <b> ( ref = s2 AND ref = s3 ) OR s5 != 'A'</b></span> <BR>
  EITHER reference genotype EQUALS to sample 2 and 3 OR sample 5 DIFFERENT than 'A'.<BR><br>
    
  Range and set of samples can be defined using the following syntax:<br>
  - Range: <span style="font-family: Arial,Helvetica,sans-serif;"><b>s3..s10</b></span><br>
  - Set: <span style="font-family: Arial,Helvetica,sans-serif;"><b>(s12,s13,s15)</b></span><br>
  <span style="font-family: Arial,Helvetica,sans-serif;">
  Example 3: <b> s2 != s3..s10 AND s11 != (s12,s13,s15)</b></span> <BR>
  Obs.: These constructs can be used in only one of the operands per each '=' and '!=' operator.<br>   
  That means that equations like <span style="font-family: Arial,Helvetica,sans-serif;"><b>'s1..s4 != s6..s10'</b></span> are not allowed. <br><br>
  
  Optionally, users can specify the number of samples from a list or range that needs to meet the imposed condition.<br>
  <span style="font-family: Arial,Helvetica,sans-serif;">
  Example 4: <b> s2 != s3..s10[6]</b></span> <BR>
  Sample 2 DIFFERENT than <b>6</b> samples within the range s3..s10<br> 
  Obs.: The usage of this construct in ranges or lists with more than 8 samples will cause a significant delay in query reponse.
  Please avoid it.<br>
    
  $sample_names_table

  Genotype equation:<br>
  <textarea rows="5" cols="60" name="genotype_equation"></textarea>

  <div id="ge_error_border">
  <span id="ge_info" style="color:red"></span>
  <pre id="ge_error" style="font-size: 13px"></pre>
  </div>

  <BR>
  
  <input name="Submit" value="Submit query!" type="submit">  
  <BR>
  <BR>

  
  <!-- Gentoype call attributes -->
  <span style="font-family: Arial,Helvetica,sans-serif;"><b>Empty values policy</b></span><BR>
  <BR>
  Some of your samples could possible have empty values for few genotype call attributes, attributes sucha as "Depth of coverage" and "Strand bias". Please choose below how to deal with those empty values during the filtering:
  <BR> 
	<input type="radio" name="all_attrib_strict" value="YES" checked="yes"/> <b> Strict filtering </b> - Genotype calls containing empty values in an attribute used in the filtering <b>will NOT</b> be shown as part of the filtered set. For example, if the users selects only genotype calls with 'strand bias' below a specific threshold value, then all genotype calls without a 'strand bias' value will be automatically filtered OUT.<br/>  	

	<input type="radio" name="all_attrib_strict" value="NO"/> <b>Relaxed filtering </b> - Genotype calls containing empty values in one of the attribute used in the filtering <b>WILL</b> be shown as part of the result.<br/>  			
  <BR>  
  
  
    
  <!-- qual-->
  <span style="font-family: Arial,Helvetica,sans-serif;">Quality score</span><BR>

  <select name="operator_one_qual">
    <option value="equals_to"> = </option>
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_one_qual" type="number">
  AND
  <select name="operator_two_qual">
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_two_qual" type="number">
 <BR>
 $qual_sample_check_box
 <BR>			   
HTML

	######################################
	## HTML for filters
	######################################

	if ( scalar( @{$filters_arr_ref} ) != 0 ) {
		$html_out .= <<HTML;
<!-- FILTERS -->
<span style="font-family: Arial,Helvetica,sans-serif;"><b>Filtering OUT:</b></span><BR>
HTML

	}
	foreach my $curr_field_id ( @{$filters_arr_ref} ) {
		my $name = $ref_fields_hash->{$curr_field_id}{name};
		my $type = $ref_fields_hash->{$curr_field_id}{type};
		my $desc = $ref_fields_hash->{$curr_field_id}{desc};

		my $sample_check_box = generate_sample_check_boxes( $sample_list_arr_ref, $name, $type, $curr_field_id );
		
		$html_out .= <<HTML;
<INPUT type="checkbox" name=$name value="true"> $name - $desc </option>
<BR>
	$sample_check_box
HTML

		if ( scalar( @{$filters_arr_ref} ) != 0 ) {
			$html_out .= <<HTML;
<BR>
HTML

		}
	}

	$html_out .= <<HTML;
<BR>
<span style="font-family: Arial,Helvetica,sans-serif;"><b>User defined VCF fields:</b></span><BR>

HTML

	######################################
	## User defined VCF fields
	######################################

	foreach my $curr_field ( values %{$ref_fields_hash} ) {

		my $id       = $curr_field->{id};
		my $name     = $curr_field->{name};
		my $type     = $curr_field->{type};
		my $desc     = $curr_field->{desc};
		my $category = $curr_field->{field_category};

		#print "Processing $name ...\n";

		# Field TYPE

		#	'Boolean'   => "BOOL",
		#	'Integer'   => "INTEGER",
		#	'Float'     => "FLOAT",
		#	'Flag'      => "BOOL",
		#	'Character' => "varchar(1)",
		#	'String'    => "varchar(255)"

		if ( $category eq "INFO" || $category eq "FORMAT" || $category eq "FIXED" ) {
			if ( $type eq 'Integer'  ) {

				$html_out .= <<HTML;
  <!-- $name-->
  <span style="font-family: Arial,Helvetica,sans-serif;">$name</span><BR>
  <span style="font-family: Arial,Helvetica,sans-serif; font-size : 11px">$desc</span><BR>

  <select name="operator_one_$name">
    <option value="equals_to"> = </option>
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_one_$name" type="number">
  AND
  <select name="operator_two_$name">
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_two_$name" type="number">
 <BR>		
HTML

			}elsif( $type eq 'Float' ){
					
$html_out .= <<HTML;
  <!-- $name-->
  <span style="font-family: Arial,Helvetica,sans-serif;">$name</span><BR>
  <span style="font-family: Arial,Helvetica,sans-serif; font-size : 11px">$desc</span><BR>

  <select name="operator_one_$name">
    <option value="equals_to"> = </option>
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_one_$name" type="number">
  AND
  <select name="operator_two_$name">
    <option value="greater_than"> &gt; </option>
    <option value="greater_than_or_equal"> &ge; </option>
    <option value="lower_than"> &lt; </option>
    <option value="lower_than_or_equal"> &le; </option>
  </select>
  <input name="thre_two_$name" type="number">
 <BR>		
HTML
				
			}
			elsif ( $type eq 'Character' || $type eq 'String' ) {

				$html_out .= <<HTML;
			
  <!-- $name-->
  <span style="font-family: Arial,Helvetica,sans-serif;">$name</span><BR>
  <span style="font-family: Arial,Helvetica,sans-serif; font-size : 11px">$desc</span><BR>
  <input name="$name">
  <BR>
HTML
			}
			elsif ( $type eq 'Boolean' || $type eq 'Flag' ) {

				$html_out .= <<HTML;
			
  <!-- $name-->
  <span style="font-family: Arial,Helvetica,sans-serif;">$name</span><BR>
  <span style="font-family: Arial,Helvetica,sans-serif; font-size : 11px">$desc</span><BR>
	<input type="radio" name="$name" value="disregard" checked="yes"/> Disregard<br/>  	
	<input type="radio" name="$name" value="true" /> True<br/>
	<input type="radio" name="$name" value="false" /> False<br/>
	<BR>
HTML
			}
			else {
				die "Unknown field type \'$type\'\n";
			}
			my $sample_check_box = generate_sample_check_boxes( $sample_list_arr_ref, $name, $type, $id );
			$html_out .= <<HTML;
	$sample_check_box
	<BR>	
HTML

		}

	}

	return ($html_out);
}

sub generate_results_html {
	my ( $ref_fields_hash, $sample_list_arr_ref, $project_name, $filters_arr_ref, $genomeview_enabled, $jbrowse_enabled ) = @_;
	
	
	my $original_dataset_name = $project_name;
 	$original_dataset_name =~ s/_sorted$//;
	
	
	# $dump_file_header contains the header of the dump file, file generated when user clicks download in the web front-end
	my $dump_file_header = '';
			
	my $html_out = "";

	if( $genomeview_enabled ){
		$html_out .= <<HTML;
 	  <a href="http://$CASA::GENOMEVIEW_URL/" target="_blank"> Start Genomeview </a> <br>
HTML
	}


	$dump_file_header .= "chrom\\tposition\\treference\\tlocus\\tgene annotation\\t";
	
	$html_out .= <<HTML;

[% nt_grid_html %]

<BR>
  <span style="font-family: Arial,Helvetica,sans-serif;">
   <b>SYN</b>-synonymous substitution,
   <b>NSY</b>-synonymous substitution, 
   <b>NON</b>-premature STOP codon, 
   <b>RTH</b>-readthrough, disrupted STOP codon.
  </span>
	
  <div style="overflow:auto; width:100%">
    <table  cellpadding="0" cellspacing="0" style="width:100%;">
        <tr>
            <td> 
  
            <table id=mainTbl>
 		<tr>
 			<!-- Chromosome -->
 				<th><span title="header=[<img src='/templates/casa/javascript/info.gif' style='vertical-align:middle'>] body=[Chromosome]" style="cursor:pointer">Chromosome</span></th>

 			<!-- SNPchromosomic coordinates -->
 				<th><span title="header=[<img src='/templates/casa/javascript/info.gif' style='vertical-align:middle'>] body=[SNP chromosomic coordinates]" style="cursor:pointer">Coordinates</span></th>
 				 				
 			<!-- Reference -->
 				<th><span title="header=[<img src='/templates/casa/javascript/info.gif' style='vertical-align:middle'>] body=[Reference]" style="cursor:pointer">Reference</span></th>
 				
 			<!-- Gene -->
 				<th><span title="header=[<img src='/templates/casa/javascript/info.gif' style='vertical-align:middle'>] body=[Gene]" style="cursor:pointer">Gene</span></th>

 			<!-- Gene annotation-->
 				<th><span title="header=[<img src='/templates/casa/javascript/info.gif' style='vertical-align:middle'>] body=[Gene annotation]" style="cursor:pointer">Gene annotation</span></th>
 				
 		
HTML
	for (
		my $cont_samples = 0 ;
		$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
		$cont_samples++
	  )
	{
		my $sample_name = $sample_list_arr_ref->[$cont_samples];
		$sample_name =~ s/_TY-2482.filtered.90pct\S+//;
		my $sample_alias = "s$cont_samples";
		my $header       = $sample_name . " ($sample_alias)";
		my $header_subst_type = "subst.type ($sample_alias)";
		my $header_full_annot = "full annot. ($sample_alias)";

		my $header_dmp            = $sample_name . "($sample_alias)";
		my $header_subst_type_dmp = "subst.type($sample_alias)";

		$dump_file_header .= "$header_dmp\\t";
		$dump_file_header .= "$header_subst_type_dmp\\t";
		$dump_file_header .= "$header_full_annot\\t" if ( $dump_full_annot );
		
		

		
		$html_out .= <<HTML;

 			<!-- $header -->
 				<th><span title="header=[<img src='/templates/casa/javascript/info.gif' style='vertical-align:middle'>] body=[$header]" style="cursor:pointer">$header</span></th>

 			<!-- $header substitution type -->
 				<th><span title="header=[<img src='/templates/casa/javascript/info.gif' style='vertical-align:middle'>] body=[substitution type($sample_alias)]" style="cursor:pointer">$header_subst_type</span></th>
 				
 				
HTML

	}

	# (2 x samples) + chrom + reference + position + gene + gene_annotation =  3 x samples + 5
	my $rows = 2 * scalar( @{$sample_list_arr_ref} ) + 5;
	
			
	$html_out .= <<HTML;
</tr>
 		[% USE table(results_table, rows=$rows) %]
 		<tr>
 		[% FOREACH cols = table.cols %]
 			[% FOREACH item = cols  %] 			    
HTML
  				

	my $onclick_cmds = "";
	
	if( $genomeview ){
		$onclick_cmds .= "javascript:setInstructAllInstancesGV();javascript:positionGV('[% cols.0 %]:[% cols.1 - 50 %]:[% cols.1 + 50 %]');";
	}
	
	if( $jbrowse ){
		$onclick_cmds .= "javascript:set_jbrowse_location('$original_dataset_name','[% cols.0 %]:[% cols.1 - 50 %]..[% cols.1 + 50 %]','');";
	}
	

	if( $genomeview || $jbrowse ){
		$html_out .= <<HTML;
  				<td><font size=1> <a href="#" onClick="$onclick_cmds">[% item %]</a> </font></td>
HTML
	}else{
		$html_out .= <<HTML;
  				<td><font size=1> [% item %]</font></td>
HTML
		
	}

	$html_out .= <<HTML;
 			[% END %]
 		</tr>
 		[% END %]				
 		</table>
          </td>
        </tr>
    </table>
    </div>
HTML
    
    	if( $jbrowse ){
    	    
	$html_out .= <<HTML;

	<br>
	<br>
	<iframe id="jbrowse_iframe" style="border: 1px solid #505050;"
	src="http://aspgd.broadinstitute.org/jbrowse/?data=data/$original_dataset_name" 
	height="700" width="850">
	</iframe>
	
	
HTML
	}
    

	#Removing surplus tab
	$dump_file_header =~ s/\\t$/\\n/;

	return ($html_out, $dump_file_header);
}

sub generate_back_end_code {
	my ( $ref_fields_hash, $sample_list_arr_ref, $project_name, $filters_arr_ref, $dump_file_header ) = @_;
	my $pm_name = $project_name . "_back_end";

	my $code_out .= <<CODE;
package DatabaseSpecificBackEnd;

use GenotypeEquations;

CODE
	
	# These are the declarations of headers and columns of the 
	# nucleotide grid shown on the results page
	my $num_samples =scalar( @{$sample_list_arr_ref} );
	my $array_header_declaration = nt_grid_header_list( $num_samples );
	my $array_col_declaration    = nt_grid_col_list( $num_samples );
	
	
	# is_strict is a variable that dictates how empty values will be treated.
	# Currently it can be only turned on or off for all attributes and samples. This functionality
	# was usually initially implemented with higher grandulitly: is_strict could be applied
	# to each sample and attribute separately. I didn want to remove the internal code
	# that deals with this level of granularity so I can eventually provide as an advanced feature
	# to users. But for the time being, for the sake of simplicity, I will use the ALL or nothing solution.
	# The variable below is necessary to implement this temporary solution without modifying most
	# of the code.
	my $string_with_all_sample_alias = "";
	for (
		my $cont_samples = 0 ;
		$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
		$cont_samples++
	  ){		
		$string_with_all_sample_alias  .= "s$cont_samples%";
	}					
	
	
	
	$code_out .= <<CODE;

\@NT_GRID_HEADER = $array_header_declaration;
\@NT_GRID_COLS = $array_col_declaration;
\$DUMP_FILE_HEADER = \"$dump_file_header\";

sub generate_where{
	
		my (\$params) = \@_;

		my \$operator_one;
		my \$operator_two;
		my \$thre_one;
		my \$thre_two;
		my \$value;
		my \$is_strict; 
		my \$filter_these = \$params->{filter_these};
		my \$all_attrib_strict = \$params->{all_attrib_strict};
		my \$add_where = "";
		my \$string_with_all_sample_alias = "$string_with_all_sample_alias";
		
		my \$chrom = \$params->{chrom};
		my \$chrom_coord_start = \$params->{chrom_coord_start};
		my \$chrom_coord_end = \$params->{chrom_coord_end};
		
		
		# is_strict is a variable that dictates how empty values will be treated.
		# Currently it can be only turned on or off for all attributes and samples. This
		# functionality was usually initially implemented with higher grandulitly: is_strict could 
		# be applied to each sample and attribute separately. I didn want to remove the internal 
		# code that deals with this level of granularity so I can eventually provide as an advanced 
		# feature to users. But for the time being, for the sake of simplicity, I will use the ALL 
		# or nothing solution.

		\$is_strict    = "$string_with_all_sample_alias" if \$all_attrib_strict eq 'YES';
		\$is_strict    = "" if \$all_attrib_strict eq 'NO';
				
		

		# Genomic coordinates
		if( \$chrom ne "all" ){
			\$add_where .= "chrom = \'\$chrom\' AND ";
		}

		if( \$chrom_coord_start ne "" ){
			\$add_where .= "position >= \$chrom_coord_start AND ";
		}
		if( \$chrom_coord_end ne "" ){
			\$add_where .= "position <= \$chrom_coord_end AND ";
		}						
		
							

		# Genotype equation
		my \$genotype_equation = \$params->{genotype_equation};
		
		if( \$genotype_equation ne "" ){	
			\$genotype_equation = GenotypeEquations::expand( \$genotype_equation );						
			\$add_where .= \$genotype_equation . " AND ";
		}		

		# Number of differences when compared to reference
		\$operator_one    = \$params->{operator_one_diff_reference};
		\$operator_two    = \$params->{operator_two_diff_reference};
		\$thre_one        = \$params->{thre_one_diff_reference};
		\$thre_two        = \$params->{thre_two_diff_reference};
		
		if( \$thre_one ne "" ){
			\$operator_one = mysql_numeric_op( \$operator_one );
			\$add_where .= "num_samples_diff_reference \$operator_one \$thre_one  AND ";
		}
			
		if( \$thre_two ne "" ){
			\$operator_two = mysql_numeric_op( \$operator_two );
			\$add_where .= "num_samples_diff_reference \$operator_two \$thre_two  AND ";
		}

		
		# Var_type
		\$value    = \$params->{var_type};
		if( \$value ne "disregard" ){
			\$add_where .= "var_type  like \'%\$value%\' AND ";
		}
		
		
		# All attributes strict filtering
		\$all_attrib_strict = \$params->{all_attrib_strict};
				
		
CODE

$code_out .= <<'CODE';

		# Gene		
		$value    = $params->{gene};
		if( $value ne "" ){
			my $gene = $value;
			
			# Removing spaces from ends
			$gene =~ s/^\s+//;
			$gene =~ s/\s+$//;
			
			# If gene is quoted try exact match 
			if( $gene =~ /\'[\w\W]+?\'/ ){
				$add_where .= "gene like $gene AND ";
			}else{
				$add_where .= "gene like   \'%$gene%\' AND ";			
			}
			
		}			


		# Gene annotation		
		$value    = $params->{gene_annotation};
		if( $value ne "" ){

			my $gene_annotation = $value;
			
			# Removing spaces from ends
			$gene_annotation =~ s/^\s+//;
			$gene_annotation =~ s/\s+$//;
						
			$add_where .= "gene_annotation like   \'%$gene_annotation%\' AND ";
		}			



		# Void
		$value    = $params->{void};
		
		if( $value ne "" ){
			my @void_samples = split( '%', $value );

			# Creates a string of bits representing all the samples that are valid
			# this is the equivalent of negating the bit string representing all void samples
			my $negate_bit_string = GenotypeEquations::sample_list_to_negate_bit_string( \@void_samples, 
			
CODE

$code_out .= "$num_samples );";			
			
$code_out .= <<'CODE';			
			# The commmand below performs a bitwise AND operation between a bit string representing all valid 
			# samples against the bit string representing all samples which are different than 
			# the reference. The result consists of all VALID samples which are different than the 
			# reference. 
			# Then, all 0 are removed (replace cmd) from this bit string and left over 1's are counted (length cmd).
			# The result represents the number of VALID samples which are different than the reference.
			# This number should be at least one
			$add_where .= " length ( replace( ( B\'$negate_bit_string\' & diff_reference )::text,'0','' ) ) >= 1 AND ";
			
		}
CODE

#################################################################
# Processed fields (mostly from Brians script)
# variance type and subtitution type


		for my $name ("var_syn_nsyn" ){
				my $str = "\$add_where .= \"( \";\n";
					
				for (
					my $cont_samples = 0 ;
					$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
					$cont_samples++
				  )
				{
					my $sample_name  = "s$cont_samples";
					my $sample_field = $name . '[' . $cont_samples . ']';
					$str .= "\$add_where .= \"$sample_field  like \\\'\%\$value%\\\' OR \";\n";
				}
				$str =~ s/OR \";\n$/) AND \";\n/;
				$code_out .= <<CODE;				
		\$value    = \$params->{$name};
		if( \$value ne "disregard" ){
			$str
		}
CODE

		}

#################################################################




	foreach my $curr_field ( values %{$ref_fields_hash} ) {

		my $id       = $curr_field->{id};
		my $name     = $curr_field->{name};
		my $type     = $curr_field->{type};
		my $desc     = $curr_field->{desc};
		my $category = $curr_field->{field_category};

		#print "Processing $name ...\n";

		# Field TYPE

		#	'Boolean'   => "BOOL",
		#	'Integer'   => "INTEGER",
		#	'Float'     => "FLOAT",
		#	'Flag'      => "BOOL",
		#	'Character' => "varchar(1)",
		#	'String'    => "varchar(255)"

		if ( $category eq "INFO" || $category eq "FORMAT" || $category eq "FIXED" ) {


			
			#################
			# Numeric fields
			
			if ( $type eq 'Integer' || $type eq 'Float' ) {

				my $str_one = "";
				my $str_two = "";
				for (
					my $cont_samples = 0 ;
					$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
					$cont_samples++
				  )
				{
					my $sample_name  = "s$cont_samples";					
					my $sample_field = $id . '[' . $cont_samples . ']';

$str_one .= <<STR_ONE;										 						
					if( \$filter_these =~ "$sample_name%" ){
						if( \$is_strict =~ "$sample_name%" ){
						 	\$add_where .= "( $sample_field  \$operator_one \$thre_one ) AND ";
						 							
						}else{
						 	\$add_where .= "( $sample_field  \$operator_one \$thre_one OR $sample_field is NULL ) AND ";																		
						}
					}
STR_ONE

$str_two .= <<STR_TWO;										 						
					if( \$filter_these =~ "$sample_name%" ){
						if( \$is_strict =~ "$sample_name%" ){

						 	\$add_where .= "( $sample_field  \$operator_two \$thre_two ) AND ";						
						}else{
						 	\$add_where .= "( $sample_field  \$operator_two \$thre_two OR $sample_field is NULL ) AND ";																		
						}
					}
STR_TWO


				}

				$code_out .= <<CODE;
		\$operator_one    = \$params->{operator_one_$name};
		\$operator_two    = \$params->{operator_two_$name};
		\$thre_one        = \$params->{thre_one_$name};
		\$thre_two        = \$params->{thre_two_$name};
		
		# $name
		if( \$thre_one ne "" ){
			\$operator_one = mysql_numeric_op( \$operator_one );
			$str_one
		}			
		if( \$thre_two ne "" ){
			\$operator_two = mysql_numeric_op( \$operator_two );
			$str_two
		}
CODE

			}
			
			##########################
			# Charact or String fields
			
			elsif ( $type eq 'Character' || $type eq 'String' ) {

				my $str = "";
				for (
					my $cont_samples = 0 ;
					$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
					$cont_samples++
				  )
				{
					my $sample_name  = "s$cont_samples";
					my $sample_field = $id . '[' . $cont_samples . ']';

$str .= <<STR;										 						
					if( \$filter_these =~ "$sample_name%" ){
						if( \$is_strict =~ "$sample_name%" ){
						 	\$add_where .= "( $sample_field = \'\$value\' ) AND ";																		
						 							
						}else{
						 	\$add_where .= "( $sample_field = \'\$value\' OR $sample_field is NULL ) AND ";																		
						}
					}
STR
					
				}

				$code_out .= <<CODE;
				
		\$value    = \$params->{$name};
		if( \$value ne "" ){
			$str
		}
CODE

			}
			elsif ( $type eq 'Boolean' || $type eq 'Flag' ) {
				my $str = "";
				for (
					my $cont_samples = 0 ;
					$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
					$cont_samples++
				  )
				{
					my $sample_name  = "s$cont_samples";
					my $sample_field = $id . '[' . $cont_samples . ']';
					
$str .= <<STR;										 						
					if( \$filter_these =~ "$sample_name%" ){
						if( \$is_strict =~ "$sample_name%" ){
						 	\$add_where .= "( $sample_field = \'\$value\' ) AND ";																		
						 							
						}else{
						 	\$add_where .= "( $sample_field = \'\$value\' OR $sample_field is NULL ) AND ";																		
						}
					}
STR

				}

				$code_out .= <<CODE;
				
		\$value    = \$params->{$name};
		if( \$value ne "disregard" ){
			$str
		}
CODE
			}

		}
	}

	###################################
	# Generating filters back-end
	###################################

	foreach my $item ( @{$filters_arr_ref} ) {

		my $str = "";
		for (
			my $cont_samples = 0 ;
			$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
			$cont_samples++
		  )
		{

			my $sample_name         = "s$cont_samples";
			my $sample_field_prefix = $item . "_filter[" . $cont_samples . "]";

			# Turning on the following filter
			# To turn it on you need to set the property associated to that filter
			# (ex. PoorMapping) to FALSE

$str .= <<STR;										 						
					if( \$filter_these =~ "$sample_name%" ){
						if( \$is_strict =~ "$sample_name%" ){
						 	\$add_where .= "( $sample_field_prefix  = false ) AND ";																		
						 							
						}else{
						 	\$add_where .= "( $sample_field_prefix  = false  OR $sample_field_prefix is NULL ) AND ";																		
						}
					}
STR
			
		}

		$code_out .= <<CODE;
		\$value    = \$params->{$item};		
				
		if( \$value ne "" ){				 				 
					$str
		}		
CODE
	}

###################################

	$code_out .= <<CODE;
		if( \$add_where ne "" ){
			\$add_where =~ s/ AND \$//;
			\$add_where = " where \$add_where ";
		}
		return \$add_where;
	}
	
sub mysql_numeric_op{
	my (\$op_str) = \@_;
	
	my \$op_mysql;
	
	\$op_mysql = ">"  if( \$op_str eq "greater_than" );
	\$op_mysql = ">=" if( \$op_str eq "greater_than_or_equal" );
	\$op_mysql = "<"  if( \$op_str eq "lower_than" );
	\$op_mysql = "<=" if( \$op_str eq "lower_than_or_equal" );
	\$op_mysql = "="  if( \$op_str eq "equals_to" );
	
	return \$op_mysql;
}

sub generate_order_by{
	return "order by $project_name.id_key_sorted";
}

CODE

	my $select_from = "select chrom, position, reference, gene, gene_annotation, ";
	my $dump_select_from = "select chrom, position, reference, gene, gene_annotation, ";
	for (
		my $cont_samples = 0 ;
		$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
		$cont_samples++
	  )
	{
		$select_from .= "alt[" . $cont_samples . "], ";
		$select_from .=  "var_syn_nsyn[" . $cont_samples . "], ";
		
		$dump_select_from .=   "alt[" . $cont_samples . "], ";   
		$dump_select_from .=   "var_syn_nsyn[" . $cont_samples . "], ";   
		$dump_select_from .=   "full_annot[" . $cont_samples . "], ";   
	}
	
	$select_from =~ s/, $/ from $project_name /;
	
	my $full_annot_table = $project_name;
	$full_annot_table =~ s/_sorted//;
	$full_annot_table .= "_full_annot"; 
	
	$dump_select_from =~ s/, $//;
	$dump_select_from .= " from $project_name " .
	     "INNER JOIN $full_annot_table ON ( $project_name.id_key_sorted = $full_annot_table.id_key_sorted ) ";

	$code_out .= <<CODE;
sub generate_select_from{
	return "$select_from";
}
CODE

if( $dump_full_annot ){

	$code_out .= <<CODE;
sub generate_dump_select_from{
	return "$dump_select_from";
}
CODE

}else{

	$code_out .= <<CODE;
sub generate_dump_select_from{
	return "$select_from";
}
CODE
	
	
}


	$code_out .= <<CODE;
return 1;
CODE
	return ($code_out);
}


# These are functions that generate the 
# declarations of headers and columns of the 
# nucleotide grid shown on the results page

# In case of 21 samples the result should be
#qw(chrom pos ref 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 );

sub nt_grid_header_list{
	my ($sample_num) = @_;
	
	my $str = "qw( chrom pos ref ";
	
	for(my $ind = 0; $ind < $sample_num; $ind++ ){
		$str .= "$ind ";
	}
	
	$str .= ")";
	return $str
}

# In case of 21 samples the result should be
# qw( 1 2 3 6 8 10 12 14 16 18 20 22 24 26 28 30 32 34 36 38 40 42 44 46 48 );
sub nt_grid_col_list{
	my ($sample_num) = @_;

	my $str = "qw( 1 2 3 ";
	my $number_of_sample_based_fields = 2;
	
	for(my $ind = 0; $ind < $sample_num; $ind++ ){
		my $col_num = 6 + ( $ind * $number_of_sample_based_fields );
		$str .= "$col_num ";
	}
	
	$str .= ")";
	return $str
}

sub generate_sample_names_table {
	my ($sample_list_arr_ref) = @_;

	my $html = <<HTML;
	
   <div id="tableContainer" class="tableContainer">
<table border="0" cellpadding="0" cellspacing="0" width="100%" class="scrollTable">
<thead class="fixedHeader">
	<tr>
        	<th>Alias</th><th>Sample name</th><th>DO NOT SHOW</th><th>Apply filter ONLY to these samples</th><th>DO NOT REPORT positions in which this/these SAMPLE(s) are the only difference(s) to the REFERENCE</th>
	</tr>
</thead>
<tbody class="scrollContent">
HTML
	for (
		my $cont_samples = 0 ;
		$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
		$cont_samples++
	  )
	{
		my $sample_name = $sample_list_arr_ref->[$cont_samples];

		my $sample_alias = "s$cont_samples";

		$html .= <<HTML;
		              <tr>
		              <td> $sample_alias </td><td>$sample_name </td>		              
		              <td><INPUT type="checkbox" name=do_not_show value="$sample_alias%"></td>
		              <td><INPUT type="checkbox" name=filter_these value="$sample_alias%" CHECKED></td>
		              <td><INPUT type="checkbox" name=void value="$sample_alias%"></td>
		              </tr>
HTML

	}

	$html .= <<HTML;
</tbody>
</table>
</div>
HTML
	return $html;

}

sub generate_sample_check_boxes {
	my ( $sample_list_arr_ref, $field_name, $field_type, $field_id ) = @_;
	

	my $html = <<HTML;
<BR>
 <!-- <span style="font-family: Arial,Helvetica,sans-serif; font-size : 11px">Impose it to:</span> -->
 <div style="overflow:auto; width:100%">
    <table cellpadding="0" cellspacing="0" style="width:100%;">
        <tr>
HTML

	# Variable that store the actual content of all cells of the table
	# This will be used to evaluate if the table has non-empty content
	# Otherwise (content is empty) this function will return nothing 
	# instead of an empty HTML table
	my $table_content = '';

	for (
		my $cont_samples = 0 ;
		$cont_samples < scalar( @{$sample_list_arr_ref} ) ;
		$cont_samples++
	  )
	{
		my $sample_name = "s$cont_samples";
		my $sample_num  = $cont_samples;
		my $checked     = "CHECKED";
		my $sample_field      =  $field_id . "[" . $sample_num . "]";
		
		# Removing characters from field that could possibly create problems
		# when using it to name files
		my $file_system_friendly_field = $sample_field;
		$file_system_friendly_field =~ s/[\[\]]/_/g;
		
		my $box_plot_img      = "box_plot." . $project_name . "." . $file_system_friendly_field . ".png";
		my $box_plot_dir      = "http://$CASA::WEB_SERVER_AND_PORT/images";
		my $box_plot_path     = $box_plot_dir . "/" . $box_plot_img;

		my $cell_content = '';
		
#		$cell_content .= <<HTML;
#			<INPUT type="checkbox" name=is_strict_$field_name value="$sample_name%" $checked> 
#		              $sample_name 
#		              </option> -->
#HTML


		
		
		if( $boxplot && ( $field_type eq "Float" || $field_type eq "Interger" )  ){

			my $number_non_null_values = boxplot( $project_name, $sample_field );

			
			if( $number_non_null_values != 0  ){
				$cell_content .= <<HTML;
		              <img src="$box_plot_path">
HTML
			}else{
				$cell_content .= <<HTML;
		              <b>NO VALUES</b>
HTML
			}



		}
		
		

		$html .= <<HTML;
			     <td><font size=1>
			     $cell_content
		              </td>
HTML
		$table_content .= $cell_content;


	}
	
	$html .= <<HTML;
        </tr>
    </table>
</div> 		
<BR>
HTML
	return '' if $table_content eq '';
	return $html;

}

sub boxplot {
	my ( $project_name, $field ) = @_;
	
	$log->info("Generating box plot for field \'$field\'...\n");
	
	# Removing characters from field that could possibly create problems
	# when using it to name files
	my $file_system_friendly_field = $field;
	$file_system_friendly_field =~ s/[\[\]]/_/g;

	my $filename_base = "box_plot." . $project_name . "." . $file_system_friendly_field;
	my $path          = $CASA::TEMPLATE_DIR . "/images/";
	my $R_script_file = $path . $filename_base . ".R";
	my $query_result  = $path . $filename_base . ".txt";
	my $boxplot_graph = $path . $filename_base . ".png";
	
	

	# OUTFILE is the generateed R_script
	open( OUTFILE, ">$R_script_file" ) || croak "Creation of results file failed: $R_script_file.\n\t$!\n";

	# OUTFILE2 is the query result file
	open( OUTFILE2, ">$query_result" ) || croak "Creation of results file failed: $R_script_file.\n\t$!\n";

	#DBI variables
	my ( $dbh, $sth );

	#connects to databse
	$dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD )
	  or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n"
	  . DBI->errstr;

	#print "Field: $field\n";
	#return if $field !~ "qual";

	my $query = "select $field from $project_name where $field is not NULL;";
	print "Query: $query\n";

	#execute query
	$sth = $dbh->prepare($query);
	$sth->execute() or die "Can't execute SQL statement:\n$query\n", $sth->errstr(), "\n";


	my $num_records = 0;
	while ( my @row_array = $sth->fetchrow_array() ) {
		print OUTFILE2 "@row_array\n";
		$num_records++;
	}
	die "Problem in fetchrow_array(): ", $sth->errstr(), "\n" if $sth->err();

	$dbh->disconnect();

	print "Number of non-NULL values: " . $num_records . "\n"; 
	
	# Return if there is no valid values on this field
	return 0 if $num_records == 0;

	# prints out the R code for the script
	print OUTFILE "polydb_data<-read.table(\"$query_result\")\;\n";
	print OUTFILE "attach(polydb_data)\;\n";
	print OUTFILE "png(filename = \'$boxplot_graph\', width = 80, height = 120)\;\n";
	print OUTFILE "par(oma=c(0,0,0,0))\;\n";
	print OUTFILE "par(mar=c(0,2,0,0))\;\n";
	print OUTFILE "boxplot(V1,data=V1,outline=FALSE)\;\n";

	print OUTFILE "dev.off()\;\n";
	close OUTFILE;

	# Uses R to generate plot
	IPCHelper::RunCmd( [ $R_exe, '--no-save', '<', $R_script_file ] , "Unable to generate boxplot for for field \'$field\'" );
	#IPCHelper::RunCmd( [ $R_exe , '--version' ] , "Unable to generate boxplot for for field \'$field\'" );
	return $num_records;

}

	
	
	
	
	
	

