package VCFDB_OFFLINE;

use Log::Log4perl;

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

my %PG_FIELD_TYPE_TRANSLATION = (
	'Boolean'   => "BOOL",
	'Integer'   => "INTEGER",
	'Float'     => "FLOAT",
	'Flag'      => "BOOL",
	'Character' => "varchar(1)",
	'String'    => "varchar(255)",
	'Text'      => "text"
	);

my %CSV_FIELD_TYPE_TRANSLATION = (
	'Boolean'   => "varchar",
	'Integer'   => "varchar",
	'Float'     => "varchar",
	'Flag'      => "varchar",
	'Character' => "varchar",
	'String'    => "varchar"
	);



my $query_set_variance_length = "update #project_name " .
	" set var_length[#sample_num] = " .
	" abs( length(alt[#sample_num]) - length(reference) )" .
	" where ( var_type like \'DELETION\' OR " .
	" var_type like \'INSERTION\' );";

my $query_set_substitution_type_indel = "update #project_name " .
	" set var_syn_nsyn[#sample_num] = \'INDEL\'" .
	" where length(alt[#sample_num]) != length(reference) AND" .
	" ALT[#sample_num] not like \'%,%\';";

my $query_set_substitution_type_none = "update #project_name " .
	" set var_syn_nsyn[#sample_num] = '' " .
	" where length(alt[#sample_num]) != length(reference) AND" .
	" ALT[#sample_num] like \'%,%\';";

# DEPRECATED
# Brians scripts interpret those as deletion. Fixing it on old DATABASES. NOT NEED IT ANYMORE
# 7000000184540634        41517   .       GA      .       134.83  PASS    AC=0;AF=0.00;AN=2;DP=125;MQ=54.80;MQ0=0 GT:DP   0/0:125 CDS,7000007077914484,7000007077914485,hypothetical protein,trans_orient:+,loc_in_cds:630,codon_pos:3,codon:ATG,DELETION[-1]
my $query_set_substitution_type_none_in_case_of_fake_variant = "update #project_name " .
	" set var_syn_nsyn[#sample_num] = '' " .
	" where var_syn_nsyn[#sample_num] = 'INDEL' AND " .
	" alt[#sample_num] = '';";


my $query_set_substitution_type_ncoding = "update #project_name " .
	" set var_syn_nsyn[#sample_num] = \'NCODING\'" .
	" where alt[#sample_num] != reference and " .
	" length(alt[#sample_num]) = length(reference) and " .
	" gene is NULL and gene_annotation is NULL and " .
	" var_syn_nsyn[#sample_num] is NULL;";

my $query_set_sample_values_equal_empty = "update #project_name " .
	" set alt[#sample_num] = \'\' " .
	" where alt[#sample_num] is NULL;";

my $query_set_equal_ref_values_to_empty = "update #project_name " .
	" set alt[#sample_num] = \'\' " .
	" where alt[#sample_num] = reference;";                                    

#sub generate_table_schema_populate_vcf_fields_table {
#	my ( $ref_fields_hash, $sample_list_arr_ref, $project_name ) = @_;
#
#	my $create_data_table_sql   = "create table $project_name (";
#	my $insert_vcf_fields_table = "";
#
#	foreach my $curr_field ( values %{$ref_fields_hash} ) {
#
#		my $name = $curr_field->{name};
#		my $type = $curr_field->{type};
#		my $desc = $curr_field->{desc};
#
#		#print "Processing $name ...\n";
#
#		# Field NAME
#		$create_data_table_sql .= $name . " ";
#
#		my $trans_type = $FIELD_TYPE_TRANSLATION{$type};
#
#		# Dies if unknown type
#		die "Unable to tranlate to MySQL format the VCF type \'"
#		  . $type
#		  . "\' from field \'"
#		  . $name . "\'\n"
#		  if ( not defined $trans_type );
#
#		# Field TYPE
#		$create_data_table_sql .= $trans_type . " ";
#
#		# Field COMMENTS (Description)
#		# $create_data_table_sql .= "COMMENT \'" . $desc . "\', ";
#
#		# Populate vcf_field table
#		$insert_vcf_fields_table .= "insert into vcf_fields(project,name,desc,type)"
#		  . " values ($project_name,$name,$desc,$type);\n";
#
#	}
#
#	$create_data_table_sql =~ s/, $/);/;
#	return ( $create_data_table_sql, $insert_vcf_fields_table );
#}






sub postgres_generate_joined_table_schema_populate_vcf_fields_table {
	my ( $ref_fields_hash, $sample_list_arr_ref, $project_name ) = @_;
	
	my $log = Log::Log4perl->get_logger();
	
	my $create_data_table_sql = "drop table if exists $project_name;" . 
		"create table $project_name ( id_key SERIAL PRIMARY KEY, \n";
	
	# This will prevent inserts containing the same content (chrom, position, reference, var_type)
	my $create_ref_based_indexes = "ALTER TABLE $project_name ADD CONSTRAINT unique_coord___$project_name UNIQUE (chrom,position,reference,var_type);\n";
	
	my $create_sample_based_indexes = "";
	
	my $insert_vcf_fields_table = "";
	
	# Table containing full annotation retrieved from Brians script
	my $full_annot_table = $project_name . "_full_annot";
	my $create_full_annot_table_sql = "drop table if exists $full_annot_table;" .
		"create table $full_annot_table as ( select id_key_sorted, ";
	my $create_full_annot_ref_based_indexes  = "create index " . $full_annot_table . "___id_key_sorted ON $full_annot_table (id_key_sorted);\n";	
	my $alter_full_annot_table_sql  = "alter table $full_annot_table "; 
	
	foreach my $curr_field ( values %{$ref_fields_hash} ) {
		
		my $id              = $curr_field->{id};
		my $name            = $curr_field->{name};
		my $type            = $curr_field->{type};
		my $desc            = $curr_field->{desc};
		my $reference_based = $curr_field->{reference_based};
		
		$log->debug( "Processing $name ...\n" );
		
		my $trans_type = $PG_FIELD_TYPE_TRANSLATION{$type};
		
		# Dies if unknown type
		die "Unable to tranlate to MySQL format the VCF type \'" 
		. $type
		. "\' from field \'"
		. $name
		. "\' (id=$id) \n"
		if ( not defined $trans_type );
		
		my $cont_sample     = 0;
		my $fields_on_index = "";
		
		##########################
		# Reference based fields - position, reference, var_type, id, ...
		if ($reference_based) {
			$create_data_table_sql .= $id . " " . $trans_type . ", ";
			
			$create_ref_based_indexes .=
			"create index $project_name" . "___$name ON $project_name ($id);\n\n";
			
			$create_full_annot_ref_based_indexes .=
			"create index $full_annot_table" . "___$name ON $full_annot_table ($id);\n\n";
			
			$create_full_annot_table_sql .= "$id , ";
			
			##########################
			# Sample based fields
			
		}
		else {
			#my $sample_id      = "s" . $cont_sample;
			my $new_field_name =  $id ;
			
			
			$create_data_table_sql .= $new_field_name . " " . $trans_type . "[] , ";					
			
			# This field will be part of the table <project_name>_full_annot
			if( $id eq "full_annot" ){
				$alter_full_annot_table_sql .= "add column $new_field_name $trans_type, ";					
			}
			
			# Fields on index
			$fields_on_index .= $new_field_name;
			$fields_on_index .= ", ";
			
			$fields_on_index =~ s/, $//;
			$create_sample_based_indexes .=
			"create index $project_name" . "___$id ON $project_name ($fields_on_index);\n\n";
		}
		
		$create_data_table_sql .= "\n\n";
		
		# Field COMMENTS (Description)
		# $create_data_table_sql .= "COMMENT \'" . $desc . "\', ";
		
		$desc =~ s/\'/\'\'/g;
		
		# Populate vcf_field table
		$insert_vcf_fields_table .= "insert into vcf_fields(project,id,name,desc,type)"
		. " values (\'$project_name\',\'$id\',\'$name\',\'$desc\',\'$type\');\n";
		
	}
	
	$create_data_table_sql =~ s/, \n\n$//;
	$create_data_table_sql .= ");\n";
	
	$create_full_annot_table_sql =~ s/, $//;
	$create_full_annot_table_sql .= " from " . $project_name . "_sorted );\n";
	
	$alter_full_annot_table_sql =~ s/, $//;
	$alter_full_annot_table_sql .= ";\n";
	
	return ( $create_data_table_sql,
		$create_ref_based_indexes, 
		$create_sample_based_indexes, 
		$create_full_annot_table_sql,
		$alter_full_annot_table_sql,
		$create_full_annot_ref_based_indexes,	         
		$insert_vcf_fields_table );
}


sub postgres_generate_alter_table {
	
	print "Generating alter table command ...\n";
	
	my ( $sample_num, $ref_fields_hash, $sample_list_arr_ref, $project_name ) = @_;
	
	my $alter_table_sql = "alter table $project_name ";
	
	foreach my $curr_field ( values %{$ref_fields_hash} ) {
		
		my $id   = $curr_field->{id};
		my $name = $curr_field->{name};
		my $type = $curr_field->{type};
		my $desc = $curr_field->{desc};
		
		#print "Processing $name ...\n";
		
		my $trans_type = $FIELD_TYPE_TRANSLATION{$type};
		
		# Dies if unknown type
		die "Unable to tranlate to MySQL format the VCF type \'" 
		. $type
		. "\' from field \'"
		. $name
		. "\' (id=$id) \n"
		if ( not defined $trans_type );
		
		# Field TYPE
		
		my $cont_sample = $sample_num;
		foreach my $curr_sample ( @{$sample_list_arr_ref} ) {
			my $sample_id      = "s" . $cont_sample;
			my $new_field_name = $sample_id . "___" . $id;
			$alter_table_sql .= " add " . $new_field_name . " " . $trans_type . " DEFAULT NULL, ";
			
			$cont_sample++;
		}
		
	}
	print "\tDone with parsing all fields ...\n";
	
	print "\Generating SQL to drop indexes ...\n";
	my $drop_ind = drop_previous_indexes( $ref_fields_hash, $project_name );
	print "\Generating SQL to re-create indexes ...\n";
	my $create_ind =
	postgres_create_indexes( $project_name, $sample_num, $ref_fields_hash, $sample_list_arr_ref );
	
	$alter_table_sql =~ s/, $//;
	$alter_table_sql .= ";";
	$alter_table_sql .= "\n" . $drop_ind . "\n" . $create_ind;
	return ($alter_table_sql);
}

sub drop_previous_indexes {
	my ( $ref_fields_hash, $project_name ) = @_;
	my $drop_indexes = "";
	
	foreach my $curr_field ( values %{$ref_fields_hash} ) {
		my $name = $curr_field->{name};
		$drop_indexes .= "drop index $project_name" . "___$name;\n";
	}
	
	return $drop_indexes;
}

sub postgres_create_indexes {
	my ( $project_name, $old_num_samples, $ref_fields_hash, $sample_list_arr_ref ) = @_;
	
	foreach my $curr_field ( values %{$ref_fields_hash} ) {
		
		my $id   = $curr_field->{id};
		my $name = $curr_field->{name};
		
		my $fields_on_index = "";
		my $new_field_name = $id;
		
		# Fields on index
		$fields_on_index .= $new_field_name;
		$fields_on_index .= ", ";
	}
	$fields_on_index =~ s/, $//;
	$create_indexes .=
	"create index $project_name" . "___$id ON $project_name ($fields_on_index);\n";
	
	
	return $create_indexes;
}


sub remove_homogeneous_records{
	my ( $project_name, $num_samples_in_db) = @_;	
	my $where = "where ";
	
	for ( my $sample_num = 0 ; $sample_num < $num_samples_in_db ; $sample_num++ ) {
		$where .= " ( reference =  alt[ " . $sample_num . "] OR " .
			"   alt[ " . $sample_num . "] = \'\' ) AND ";
		
	}	
	$where =~ s/AND $/;/;
	
	my $query  = "delete from $project_name " . $where;
	
	#print $query . "\n";
	#getc();
	
	return $query . "\n";
}

sub generate_table_data {
	my ( $ref_fields_hash, $project_name, $ref_data_hash ) = @_;
	
	my $prefix_sql = "insert into $project_name(";
	my $middle_sql = ") values(";
	my $suffix_sql = ");";
	
	my $fields_sql = "";
	my $values_sql = "";
	
	foreach my $curr_field_id ( keys %{$ref_data_hash} ) {
		
		my $value = $ref_data_hash->{$curr_field_id};
		my $type  = $ref_fields_hash->{$curr_field_id}{type};
		
		#Types
		# 'Boolean'
		# 'Integer'
		# 'Float'
		# 'Flag'
		# 'Character'
		# 'String'
		
		if ( $type eq 'Character' || $type eq 'String' ) {
			$value = "\'$value\'";
		}
		
		$fields_sql .= $curr_field_id . ", ";
		$values_sql .= $value . ", ";
		
	}
	$fields_sql =~ s/, $//;
	$values_sql =~ s/, $//;
	
	return $prefix_sql . $fields_sql . $middle_sql . $values_sql . $suffix_sql . "\n";
}

sub insert_into_table_data {
	my ( $ref_fields_hash, $project_name, $ref_data_hash, $num_samples ) = @_;
	
	my $prefix_sql = "insert into $project_name(";
	my $middle_sql = ") values(";
	my $suffix_sql = ");";
	
	my $fields_sql = "";
	my $values_sql = "";
	
	# Generate empty value for ALT[]
	my $alt_empty_value = '\'{';
	for( my $count = 1; $count <= $num_samples; $count++ ){
		$alt_empty_value .= '"",';
	}
	$alt_empty_value =~ s/,$//;
	$alt_empty_value .= '}\'';
	
	# Generate field subscripting for ALT
	my $alt_field_subscripting = 'alt[0:' . ($num_samples - 1) . ']';
		
	
	foreach my $curr_field_id ( 'chrom', 'position', 'id', 'reference', 'var_type' ) {
		
		my $value = $ref_data_hash->{$curr_field_id};
		my $type  = $ref_fields_hash->{$curr_field_id}{type};
		
		#Types
		# 'Boolean'
		# 'Integer'
		# 'Float'
		# 'Flag'
		# 'Character'
		# 'String'
		
		if ( $type eq 'Character' || $type eq 'String' ) {
			$value = "\'$value\'";
		}
		
		$fields_sql .= $curr_field_id . ", ";
		$values_sql .= $value . ", ";
		
	}	
	$fields_sql .= $alt_field_subscripting;
	$values_sql .= $alt_empty_value;
	
	return $prefix_sql . $fields_sql . $middle_sql . $values_sql . $suffix_sql . "\n";
}

sub update_table_data {
	my ( $ref_fields_hash, $project_name, $sample_id, $ref_data_hash ) = @_;
	
	my $prefix_sql = "update $project_name set ";
	
	my $fields_values_sql = "";
	my $chrom;
	my $position;
	my $reference;
	my $var_type;
	
	foreach my $curr_field_id ( keys %{$ref_data_hash} ) {
		
		my $name  = $ref_data_hash->{$curr_field_id}{name}; 
		my $value = $ref_data_hash->{$curr_field_id};
		my $type  = $ref_fields_hash->{$curr_field_id}{type};
		
		
		if( $value eq 'Infinity' || $value eq '-Infinity' ){
			
			# Only Float fields can have Infinity or -Infinity values
			# This is a Postgres requirement.
			# The value should be quoted
			if( $type eq 'Float' ){
				$value = "\'$value\'";
			}else{
				
				die "Error on sample/VCF $sample_id\n" .
					"There is a line in the referred sample VCF with the field \"$name\" having the special value \"$value\".\n" .
					"This field has type $type, but the special value is only permited on fields having \n" .
					"Float type!\n\n";
			}
			
		}
		
		if( $value eq 'NaN' ){	
			$value = "\'$value\'";
		}
		
		
		if ( $curr_field_id eq 'chrom' ) {
			$chrom = "\'$value\'";
			next;
		}
		elsif ( $curr_field_id eq 'position' ) {
			$position = $value;
			next;
		}
		elsif ( $curr_field_id eq 'reference' ) {
			$reference = "\'$value\'";
			next;
		}
		elsif ( $curr_field_id eq 'var_type' ) {
			$var_type = "\'$value\'";
			next;
		}
		elsif ( $curr_field_id eq 'id' ) {
			next;
		}
		
		#Types
		# 'Boolean'
		# 'Integer'
		# 'Float'
		# 'Flag'
		# 'Character'
		# 'String'
		
		if ( $value eq '' ) {
			$value = "NULL";
		}
		elsif ( $type eq 'Character' || $type eq 'String' ) {
			$value = "\'$value\'";
		}
		
		$fields_values_sql .= $curr_field_id . "[" . $sample_id . "] = " . $value . ", ";
		
		
	}
	
	my $where_sql =
	" where chrom=$chrom and position=$position and reference=$reference and var_type = $var_type;";
	
	$fields_values_sql =~ s/, $/ /;
	
	
	
	
	my $return_value = $prefix_sql . $fields_values_sql . $where_sql . "\n";
	
	return $return_value;
}

sub generate_sample_table_inserts {
	my ( $project_name, $sample_names_ref_arr, $start_sample_num ) = @_;
	
	my $sql = "";
	foreach my $curr_sample ( @{$sample_names_ref_arr} ) {
		$sql = "insert into samples(project_name, name, alias)";
	}
	
}

sub add_gene_annotation_fields_indexes {
	my ( $dbh, $project_name ) = @_;
	execute_query( $dbh, $project_name, "", $add_gene_fields );
	execute_query( $dbh, $project_name, "", $add_gene_indexes );
	execute_query( $dbh, $project_name, "", $add_gene_annot_indexes );
}

sub add_gene_annotation_fields_indexes {
	my ( $dbh, $project_name ) = @_;
	execute_query( $dbh, $project_name, "", $add_gene_fields );
	execute_query( $dbh, $project_name, "", $add_gene_indexes );
	execute_query( $dbh, $project_name, "", $add_gene_annot_indexes );
}

my $add_var_type_index_samples =
"create index var_type_#project_name ON #project_name (var_type );";

my $add_var_length_index_samples =
"create index var_length_#project_name ON #project_name (var_length );";

my $add_var_syn_nsyn_index_samples =
"create index var_syn_nsyn_#project_name ON #project_name (var_syn_nsyn );";

sub generate_gene_annotation_fields_indexes {
	my ($project_name) = @_;
	my $query = "alter table #project_name add gene varchar(45), add gene_annotation text;\n";
	$query .= "create index gene___#project_name ON #project_name (gene);\n";
	$query .= "create index gene_annotation___#project_name ON #project_name (gene_annotation);\n";
	
	$query =~ s/#project_name/$project_name/g;
	
	return $query;
}

sub generate_gene_annotation_fields_indexes_for_samples {
	my ( $project_name, $num_samples_in_db ) = @_;
	
	my $query;
	
	my $temp = "alter table #project_name add var_type varchar(45);";
	$query .= $temp . "\n";
	
	$temp = "alter table #project_name add var_length int;";
	$query .= $temp . "\n";
	
	$temp = "alter table #project_name add var_syn_nsyn varchar(45);";
	$query .= $temp . "\n";
	
	
	foreach my $field ( "var_type", "var_length", "var_syn_nsyn" ) {
		my $temp =
		"create index " . $field . "_#project_name ON #project_name";
		$temp  .= "(" . $field . ");";
		$query .= $temp . "\n";
	}
	
	$query =~ s/#project_name/$project_name/g;
	
	return $query;
}

sub adjust_variance_length{
	my ($project_name, $sample_num) = @_;		
	
	my $query = "";
	$query .= prepare_query( $project_name, $sample_num, $query_set_variance_length ) . "\n";
	
	return $query;
}

# DEPRECATED
# Brians scripts interpret those as deletion. Fixing it on old DATABASES. NOT NEED IT ANYMORE
# 7000000184540634        41517   .       GA      .       134.83  PASS    AC=0;AF=0.00;AN=2;DP=125;MQ=54.80;MQ0=0 GT:DP   0/0:125 CDS,7000007077914484,7000007077914485,hypothetical protein,trans_orient:+,loc_in_cds:630,codon_pos:3,codon:ATG,DELETION[-1]
sub fix_fake_variant{
	my ( $project_name, $sample_num) = @_;	
	
	my $query = "";		
	
	$query .= prepare_query( $project_name, $sample_num, $query_set_substitution_type_none_in_case_of_fake_variant ) . "\n";	
	return $query;
}



sub adjust_substitution_type{
	my ( $project_name, $sample_num) = @_;	
	
	my $query = "";		
	
	
	#$query .= prepare_query( $project_name, $sample_num, $query_set_substitution_type_none ) . "\n";
	
	# DEPRECATED
	# Brians scripts interpret those as deletion. Fixing it on old DATABASES. NOT NEED IT ANYMORE
	# 7000000184540634        41517   .       GA      .       134.83  PASS    AC=0;AF=0.00;AN=2;DP=125;MQ=54.80;MQ0=0 GT:DP   0/0:125 CDS,7000007077914484,7000007077914485,hypothetical protein,trans_orient:+,loc_in_cds:630,codon_pos:3,codon:ATG,DELETION[-1]
	$query .= prepare_query( $project_name, $sample_num, $query_set_substitution_type_none_in_case_of_fake_variant ) . "\n";
	
	# DEPRECATED
	#$query .= prepare_query( $project_name, $sample_num, $query_set_substitution_type_indel ) . "\n";
	# DEPRECATED
	#$query .= prepare_query( $project_name, $sample_num, $query_set_substitution_type_ncoding ) . "\n";
	
	return $query;
}

sub set_sample_values_equal_empty{
	my ( $project_name, $sample_num) = @_;		
	
	my $query = "";		
	$query .= prepare_query( $project_name, $sample_num, $query_set_sample_values_equal_empty ) . "\n";
	
	return $query;
}


sub set_equal_ref_values_to_empty{
	my ( $project_name, $sample_num) = @_;		
	
	my $query = "";		
	$query .= prepare_query( $project_name, $sample_num, $query_set_equal_ref_values_to_empty ) . "\n";
	
	return $query;
}


# Add sample_num and project to a defined SQL query	
sub prepare_query{
	my ( $project_name, $sample_num, $query ) = @_;
	
	$query =~ s/#project_name/$project_name/g;
	$query =~ s/#sample_num/$sample_num/g;
	
	#print STDERR "Query: $query\n";
	#getc();
	
	return $query;		
}

sub create_genotype_concat_field{
	my ( $project_name  ) = @_;
	
	my $query = "alter table $project_name add column genotype_concat text;\n";
	return $query;
}


sub populate_genotype_concat_field{
	my ( $project_name, $num_samples_in_db ) = @_;
	
	my $all_alt_fields;
	
	# Postgres only accepts 100 arguments per funtion
	my $MAX_ARGUMENTS_POSTGRES_FUNCTIONS = 100;
	
	my $high_level_concat;
	
	# I will need to subdivide the concat function in several concats of MAX fields each	
	for ( my $offset = 0 ; $offset < $num_samples_in_db ; $offset += $MAX_ARGUMENTS_POSTGRES_FUNCTIONS ) {
		my $low_level_concat;			
		for ( my $inc = 0 ; $inc < $MAX_ARGUMENTS_POSTGRES_FUNCTIONS; $inc++ ) {
			$sample_num = $offset + $inc;
			last if $sample_num >= $num_samples_in_db;			
			$low_level_concat .= "alt[" . $sample_num . "], ";
		}
		$low_level_concat =~ s/, $//;
		$high_level_concat .= "concat(" . $low_level_concat . "), ";
	}
	
	$high_level_concat =~ s/, $//;
	
	$high_level_concat = "concat(" . $high_level_concat . ")"; 
	
	my $query = "update $project_name set genotype_concat = $high_level_concat;\n";
	return $query;
}

sub create_genotype_concat_pipe_separated_field{
	my ( $project_name  ) = @_;
	
	my $query = "alter table $project_name add column genotype_concat_pipe_separated text;\n";
	return $query;
}

sub populate_genotype_concat_pipe_separated_field{
	my ( $project_name, $num_samples_in_db ) = @_;
	
	my $all_alt_fields;
	
	# Postgres only accepts 100 arguments per funtion
	my $MAX_ARGUMENTS_POSTGRES_FUNCTIONS = 30;
	
	my $high_level_concat;
	
	# I will need to subdivide the concat function in several concats of MAX fields each	
	for ( my $offset = 0 ; $offset < $num_samples_in_db ; $offset += $MAX_ARGUMENTS_POSTGRES_FUNCTIONS ) {
		my $low_level_concat;			
		for ( my $inc = 0 ; $inc < $MAX_ARGUMENTS_POSTGRES_FUNCTIONS; $inc++ ) {
			$sample_num = $offset + $inc;
			last if $sample_num >= $num_samples_in_db;			
			$low_level_concat .= "'|', alt[" . $sample_num . "], ";
		}
		$low_level_concat =~ s/, $//;
		$high_level_concat .= "concat(" . $low_level_concat . "), ";
	}
	
	$high_level_concat =~ s/, $/, \'\|\'/;
	
	$high_level_concat = "concat(" . $high_level_concat . ")"; 
	
	my $query = "update $project_name set genotype_concat_pipe_separated = $high_level_concat;\n";
	return $query;
}


sub create_num_samples_diff_reference_field{
	my ( $project_name  ) = @_;
	
	my $query = "alter table $project_name add column num_samples_diff_reference integer;\n";
	$query   .= "create index num_samples_diff_reference___$project_name ON $project_name (num_samples_diff_reference);\n";
	return $query;
}

sub populate_num_samples_diff_reference_field{
	my ( $project_name, $num_samples_in_db ) = @_;	
	
	# Remove from the concatenated strings genotypes = reference and commas from
	# two alleles genotypes
	my $query = "update $project_name set num_samples_diff_reference \n" .
		" = length( \n" .
		"     translate( \n" .
		"       regexp_replace( \n" .
		"         replace( \n" .
		"            genotype_concat_pipe_separated, reference, '' \n" . 
		"         ), \n" . 
		"         '\\|+', '|', 'g' \n".
		"       ), \n" .
		"       'AGCTagct,', '' \n" .
		"     ) \n" .
		"   ) - 1;\n";
	
	return $query;
}


sub create_diff_reference_field{
	my ( $project_name, $num_samples_in_db  ) = @_;
	
	my $query = "alter table $project_name add column diff_reference BIT(" .  ($num_samples_in_db ) . ");\n";
	$query   .= "create index diff_reference___$project_name ON $project_name (diff_reference);\n";
	
	return $query;
}


sub populate_diff_reference_field{
	my ( $project_name, $num_samples_in_db ) = @_;
	
	my $all_alt_fields;
	
	# Postgres only accepts 100 arguments per funtion
	my $MAX_ARGUMENTS_POSTGRES_FUNCTIONS = 100;
	
	my $high_level_concat;
	
	# I will need to subdivide the concat function in several concats of MAX fields each	
	for ( my $offset = 0 ; $offset < $num_samples_in_db ; $offset += $MAX_ARGUMENTS_POSTGRES_FUNCTIONS ) {
		my $low_level_concat;			
		for ( my $inc = 0 ; $inc < $MAX_ARGUMENTS_POSTGRES_FUNCTIONS; $inc++ ) {
			$sample_num = $offset + $inc;
			last if $sample_num >= $num_samples_in_db;
			
			$low_level_concat .= "(reference != alt[" . $sample_num . "] AND alt[" . $sample_num . "] != '' )::integer, ";			
		}
		$low_level_concat =~ s/, $//;
		$high_level_concat .= "concat(" . $low_level_concat . "), ";
	}
	
	$high_level_concat =~ s/, $//;
	
	$high_level_concat = "concat(" . $high_level_concat . ")"; 
	
	my $query = "update $project_name set diff_reference = " . $high_level_concat . "::bit(" . ($num_samples_in_db) . ");\n";
	return $query;
}

return 1;
