package VCFDB;

use VCFUtils;
use VCFDB_OFFLINE;


# Counting queries
my $query_pol = "from #project_name where ALT[#sample_num] != \'\' AND reference != ALT[#sample_num]";

#my $query_subs = "from #project_name where ALT[#sample_num] != \'\' AND reference != ALT[#sample_num] AND ( ( length(reference) = length(ALT[#sample_num]) AND length(reference) = 1 ) OR ALT[#sample_num] like \'%,%\' )";

# At least Pilon report substitutions of more than 1 bp len in ref and alt. These are reported as long insertions
# in the field SNV of the VCF
my $query_subs = "from #project_name where ALT[#sample_num] != \'\' AND reference != ALT[#sample_num] AND ( ( length(reference) = length(ALT[#sample_num]) ) OR ALT[#sample_num] like \'%,%\' )";

my $query_ins = "from #project_name where ALT[#sample_num] != \'\' AND reference != ALT[#sample_num] AND length(reference) < length(ALT[#sample_num]) AND ALT[#sample_num] not like \'%,%\'";

my $query_del = "from #project_name where ALT[#sample_num] != \'\' AND reference != ALT[#sample_num] AND length(reference) > length(ALT[#sample_num])";


# Counting queries on processed fields

my $query_subs_pre = "from #project_name where var_type like \'SUBSTITUTION\' AND ( ALT[#sample_num] != \'\' AND reference != ALT[#sample_num])";
my $query_ins_pre = "from #project_name where var_type like \'INSERTION\' AND ( ALT[#sample_num] != \'\' AND reference != ALT[#sample_num])";
my $query_del_pre = "from #project_name where var_type like \'DELETION\' AND ( ALT[#sample_num] != \'\' AND reference != ALT[#sample_num])";

#my $query_coding_indels_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%INDEL%\' AND ALT[#sample_num] != \'\'";
my $query_coding_indels_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%INDEL%\'";

my $query_user_exists = "from pg_user where usename = \'#sample_num\'";

#my $query_coding_ins_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%INDEL%\' AND var_type like \'INSERTION\' AND ALT[#sample_num] != \'\'";
#my $query_coding_del_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%INDEL%\' AND var_type like \'DELETION\' AND ALT[#sample_num] != \'\'";
my $query_coding_ins_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%INDEL%\' AND var_type like \'INSERTION\'";
my $query_coding_del_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%INDEL%\' AND var_type like \'DELETION\'"; 


my $query_ncoding_pre = "from #project_name where ( ALT[#sample_num] != \'\' AND reference != ALT[#sample_num]) AND var_syn_nsyn[#sample_num] is NULL";
my $query_ncoding_subst_pre = "from #project_name where ( ALT[#sample_num] != \'\' AND reference != ALT[#sample_num]) AND var_type like \'SUBSTITUTION\' AND var_syn_nsyn[#sample_num] is NULL";
my $query_syn_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%SYN%\'";
my $query_nsyn_pre = "from #project_name where var_syn_nsyn[#sample_num] like \'%NSY%\'";


# Execute queries
# Query that performs tasks without returning a value	
my $query_set_variance_type_none = "update #project_name " .
                                    " set var_type[#sample_num] = \'\' " .
                                    " where alt[#sample_num] = reference;";
                                                                        

my $query_set_variance_type_subst = "update #project_name " .
                                    " set var_type[#sample_num] = \'SUBSTITUTION\' " .
                                    " where alt[#sample_num] != reference AND " .
                                    " length(alt[#sample_num]) = length(reference);";

my $query_set_variance_type_ins = "update #project_name " .
                                    " set var_type[#sample_num] = \'INSERTION\' " .
                                    " where length(alt[#sample_num]) > length(reference);";

my $query_set_variance_type_del = "update #project_name " .
                                    " set var_type[#sample_num] = \'DELETION\' " .
                                    " where length(alt[#sample_num]) < length(reference);";


my $query_set_sample_values_equal_ref = "update #project_name " .
                                    " set alt[#sample_num] = reference " .
                                    " where alt[#sample_num] = \'\';";


           
sub user_exists{
	my ($dbh, $user) = @_;		
	return 	count_query( $dbh, 'void', $user, $query_user_exists );
}



sub upload_into_db{
	my ( $dbh, $query, $line_num, $line ) = @_;
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
}

sub  get_reference_values{
	my ($dbh, $project_name, $chrom, $coord) = @_;
	
	my $query = "select reference from $project_name where chrom = $chrom and position = $coord;";
	#print "Reference value query:" . $query . "\n";
	#getc();
	
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
	
	my @reference_values = $sth->fetchrow_array();
	
	#print "Reference value: " . $reference_values[0] . "\n";
	map { $_ =~ s/\'// } @reference_values;
	#print "Reference value: " . $reference_values[1] . "\n";
	#getc();		
    
    die "Problem in fetchrow_array(): ", $sth->errstr(), "\n" if $sth->err();    

	#print "Reference value: $reference\n";
	#getc();

    return @reference_values;	
}

sub  is_reference_defined{
	my ($dbh, $project_name, $chrom, $coord, $value) = @_;
	
	my $query = "select reference from $project_name where chrom = $chrom and position = $coord and reference = \'$value\';";
	#print "Reference value query:" . $query . "\n";
	#getc();
	
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
	
	my @reference_array = $sth->fetchrow_array();		
    
    die "Problem in fetchrow_array(): ", $sth->errstr(), "\n" if $sth->err();    

    return ( scalar( @reference_array ) != 0 );	
}


sub adjust_variance_type{
	my ($dbh, $project_name, $sample_num) = @_;			
	execute_query( $dbh, $project_name, $sample_num, $query_set_variance_type_none );
	execute_query( $dbh, $project_name, $sample_num, $query_set_variance_type_subst );
	execute_query( $dbh, $project_name, $sample_num, $query_set_variance_type_ins );
	execute_query( $dbh, $project_name, $sample_num, $query_set_variance_type_del );
}

sub adjust_alelles_alpha_order{
	my ($dbh, $project_name, $sample_num) = @_;		
	
	my $query = "select chrom, position, reference, var_type, s" . $sample_num . "___alt from $project_name where s" . $sample_num . "___alt like '%,%';";
	
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";

    die "Problem in fetchrow_hashref(): ", $sth->errstr(), "\n" if $sth->err();    
        
    while( my ($chrom, $position, $reference, $var_type, $alt) = $sth->fetchrow_array() ){
    	my $genotype_sorted = VCFUtils::alpha_order_alleles( $alt );	
    	my $query2 = "update anidulans_m set s" . $sample_num . "___alt = \'$genotype_sorted\' , " .
    				 " var_type = \'SUBSTITUTION\', s" . $sample_num . "___var_syn_nsyn = \'SUBSTITUTION\' " . 
    	             " where chrom = \'$chrom\' AND position = $position AND reference = \'$reference\' " .
    	             " AND var_type = \'$var_type\' ;";
    	
    	my $sth2 = $dbh->prepare($query2);
		$sth2->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
    	    	  		
    }        
}



sub set_sample_values_equal_ref{
	my ($dbh, $project_name, $sample_num) = @_;		
	
	execute_query( $dbh, $project_name, $sample_num, $query_set_sample_values_equal_ref );
}



my $add_annot_fields_samples = "alter table #project_name add var_type[#sample_num] varchar(45), add var_length[#sample_num] int, add var_syn_nsyn[#sample_num] varchar(45);";

my $add_var_type_index_samples = "create index var_type_#project_name ON #project_name ( var_type );";

my $add_var_length_index_samples = "create index var_length_#project_name ON #project_name (var_length );";

my $add_var_syn_nsyn_index_samples = "create index var_syn_nsyn_#project_name ON #project_name (var_syn_nsyn );";


sub remove_homogeneous_records{
	my ($dbh, $project_name, $num_samples_in_db) = @_;	
	my $query = VCFDB_OFFLINE::remove_homogeneous_records( $project_name, $num_samples_in_db );	
	execute_query( $dbh, $project_name, "", $query );
}


# Get num 
sub  get_num_substitutions{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_subs );
}

sub  get_num_insertions{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_ins );
}

sub  get_num_deletions{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_del );
}

sub  get_num_polymorphic_sites{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_pol );
}

# Dump 
sub  get_substitutions{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_subs );
}

sub  get_insertions{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_ins );
}

sub  get_deletions{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_del );
}

sub  get_polymorphic_sites{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_pol );
}

#####################
# Pre DB


# Get num
sub  get_num_substitutions_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_subs_pre );
}

sub  get_num_insertions_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_ins_pre );
}

sub  get_num_deletions_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_del_pre );
}

sub  get_num_coding_indels_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_coding_indels_pre );
}

sub  get_num_coding_ins_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_coding_ins_pre );
}

sub  get_num_coding_del_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_coding_del_pre );
}


sub  get_num_ncoding_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_ncoding_pre );
}

sub  get_num_ncoding_subst_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_ncoding_subst_pre );
}


sub  get_num_syn_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_syn_pre );
}

sub  get_num_nsyn_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	count_query( $dbh, $project_name, $sample_num, $query_nsyn_pre );
}


# Dump

sub  get_substitutions_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_subs_pre );
}

sub  get_insertions_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_ins_pre );
}

sub  get_deletions_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_del_pre );
}

sub  get_coding_indels_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_coding_indels_pre  );
}

sub  get_coding_ins_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_coding_ins_pre );
}

sub  get_coding_del_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_coding_del_pre );
}


sub  get_ncoding_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_ncoding_pre );
}

sub  get_ncoding_subst_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_ncoding_subst_pre );
}


sub  get_syn_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_syn_pre );
}

sub  get_nsyn_pre{
	my ($dbh, $project_name, $sample_num) = @_;		
	return 	dump_query( $dbh, $project_name, $sample_num, $query_nsyn_pre );
}

#####################

sub count_query{
	my ($dbh, $project_name, $sample_num, $query ) = @_;

	$query =  "select count(*) $query;";
	
	$query =~ s/#project_name/$project_name/g;
	$query =~ s/#sample_num/$sample_num/g;
			
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
	
	my ($num) = $sth->fetchrow_array();		
    
    die "Problem in fetchrow_array(): ", $sth->errstr(), "\n" if $sth->err();    

    return $num;	
}


sub dump_query{
	my ($dbh, $project_name, $sample_num, $query ) = @_;
	
	$query =  "select chrom, position $query order by chrom, position;";
	
	$query =~ s/#project_name/$project_name/g;
	$query =~ s/#sample_num/$sample_num/g;
			
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
	
	my $dump = "";
    while( my @cols = $sth->fetchrow_array() ){
    	die "Empty chromosome name on table $project_name" if $cols[0] eq ""; 
    	$dump .= join( " ", @cols ) . "\n";    		
    }	
    
    die "Problem in fetchrow_array(): ", $sth->errstr(), "\n" if $sth->err();    

    return $dump;	
}


# Query that performs tasks without returning a value	
sub execute_query{
	my ($dbh, $project_name, $sample_num, $query ) = @_;
	
	$query =~ s/#project_name/$project_name/g;
	$query =~ s/#sample_num/$sample_num/g;
			
	#print STDERR "Query: $query\n";
	#getc();
		
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
}


sub get_last_sample_num{
	my ($dbh, $project_name ) = @_;
	
	my $query = "select array_dims(alt) from $project_name limit 1;";
	
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
	
	
        my @cols = $sth->fetchrow_array();        
    	
    	my $last_sample;
    	if( ($last_sample) = ( $cols[0] =~ /\[0:(\d+)\]/ ) ){
    		return $last_sample;
    	}else{
    		die "Unable to retrieve the number of the last sample in the database!!!";
    	}

}



sub get_chrom_names{
	my ($dbh, $project_name ) = @_;
	
	my $query = "select distinct chrom from $project_name;";
	
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";

    die "Problem in fetchrow_hashref(): ", $sth->errstr(), "\n" if $sth->err();    
        
    my @chrom_names;
    while( my @cols = $sth->fetchrow_array() ){
    	die "Empty chromosome name on table $project_name" if $cols[0] eq ""; 
    	push @chrom_names, $cols[0];    		
    }
        
    return @chrom_names;
}

return 1;
