#!/usr/bin/env perl
use strict;
use template_code;
use DBI;

TemplateCode::execute(
	sub {
		my ($cgi,$upload_dir) =  @_;
		
		my @results_table;
		
		my $sample = $cgi->param("sample");
		my $gene   = $cgi->param("gene");

		my $dump   = $sample . "<BR>" . $gene . "<BR>";

    my $sid = $cgi->param("SID");	
    
    my $dumpFilePrefix = $sample . "_" . $gene;
    my $dumpFilePath =  $CASA::TEMPLATE_DIR . "/results";
    
    
    my $txtFileName = "$dumpFilePath/$dumpFilePrefix.$sid.fas";
    
    
    open (OUTFILE, ">", "$txtFileName") || die ("Creation of Results File failed: $!\n");
    
    my ($dbh, $sth);
    
    #connects to databse
    $dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD) or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n" . DBI->errstr;
    
    #execute query
    
    my $query = "select nt_seq from dna_sequence where sample_name like \"$sample\" and chrom like \"$gene\"";
    
    $sth = $dbh->prepare($query);
    $sth->execute();
    
    my $gene_sequence;
    while ( my @row_array = $sth->fetchrow_array() ) {
    	print OUTFILE ">sample: $sample gene: $gene\n$row_array[0]\n";
    	$gene_sequence = $row_array[0];
    }
    $gene_sequence =~ s/(\w{60})/\1\<BR\>/g;
    close OUTFILE;
    
    $dbh->disconnect();
    
		
	 	# Defining the core of the home page
		my $vars = {
			core  			  => 'gene_info',
			tab_state 		=> 'Query',
			sample        => $sample,
			gene          => $gene,
			gene_sequence => $gene_sequence,
			zipfile				=> "$dumpFilePrefix.$sid.fas",
			URL_base_dump_file => $CASA::URL_base_dump_file,
			dump 					=> $dump			
		};
		
		return ( $vars ); 
	}
	);
