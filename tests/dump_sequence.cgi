#!/bin/env perl
use strict;
use template_code;
use DBI;

TemplateCode::execute(
	sub {
		my ($cgi,$upload_dir) =  @_;
		
		my @results_table;
		
		my $query = $cgi->param("query");
		my $format = $cgi->param("format");
		
		$query =~ s/ limit \d+,\d+/;/;
		$query =~ s/ from/, ds.nt_seq from/;
		
    my $dump = $query . "<BR>";
    my $sid = $cgi->param("SID");	
    
    my $dumpFilePrefix = "arc3db_dump";
    my $dumpFilePath =  $CASA::TEMPLATE_DIR . "/results";
    
    
    my $txtFileName;
    
    $txtFileName = "$dumpFilePrefix.$sid.txt" if $format eq "tab";
    $txtFileName = "$dumpFilePrefix.$sid.fas" if $format eq "fasta";
    
    my $zipFileName = $txtFileName . ".zip";
    
    
    open (OUTFILE, ">", "$dumpFilePath/$txtFileName") || die ("Creation of Results File failed: $!\n");
    
    my ($dbh, $sth);
    
    #connects to databse
    $dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD) or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n" . DBI->errstr;
    
    #execute query
    $sth = $dbh->prepare($query);
    $sth->execute();
    
    if ( $format eq "tab" ){
    	while ( my @row_array = $sth->fetchrow_array() ) {

    		foreach my $field ( @row_array ){
    			print OUTFILE $field . "\t";
    		}
    		print OUTFILE "\n";


    	}
    	close OUTFILE;
    }elsif( $format eq "fasta" ){
    	while ( my @row_array = $sth->fetchrow_array() ) {
    		my $gene_sequence = pop @row_array;    	
    		$gene_sequence =~ s/(\w{60})/\1\n/g;
    		
    		print OUTFILE ">";
    		foreach my $field ( @row_array ){
    			print OUTFILE $field . "\t";
    		}
    		print OUTFILE "\n" . $gene_sequence . "\n";
    	}
    }
    close OUTFILE;
    
    `zip -j $dumpFilePath/$zipFileName $dumpFilePath/$txtFileName`;
    
    $dbh->disconnect();
    
    
    # Defining the core of the home page
    my $vars = {
    	core  			  => 'link_to_dump',
    	tab_state 		=> 'Query',
    	zipfile				=> $zipFileName,
    	URL_base_dump_file => $CASA::URL_base_dump_file,
    	dump 					=> $dump			
    };
    
    return ( $vars ); 
	}
	);

