#!/bin/env perl
use strict;
use template_code;
use DBI;

TemplateCode::execute(
	sub {
		my ($cgi,$upload_dir) =  @_;
		
		my @results_table;
		
		my $query                 = $cgi->param("query");
		
		
    my $dump = $query . "<BR>";
    my $sid = $cgi->param("SID");	
    my $R_script_file = "R_script_file.$sid.R";
    my $query_result = "R_query_file.$sid.txt";
    
    # OUTFILE is the generateed R_script
    open (OUTFILE, ">", $CASA::TEMPLATE_DIR . "/results/" . $R_script_file ) || die ("Creation of Results File failed: $!\n");
    # OUTFILE2 is the query result file
    open (OUTFILE2, ">", $CASA::TEMPLATE_DIR . "/results/" . $query_result ) || die ("Creation of Query Result File failed: $!\n");
    
    #DBI variables
    my ($dbh, $sth);
    
    #connects to databse
    $dbh = DBI->connect($CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD ) or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n" . DBI->errstr;
    
    #execute query
    $sth = $dbh->prepare($query);
    $sth->execute();
    
    while ( my @row_array = $sth->fetchrow_array() ) {
    	print OUTFILE2 "@row_array\n";
    }
    # prints name of query result file
    # print OUTFILE "/home/gcerqueira/local/apache2/htdocs/templates/casa/results/$query_result\n";	
    # prints out the R code for the script  
    print OUTFILE "arc3_data<-read.table(\"/home/gcerqueira/local/apache2/htdocs/templates/casa/results/$query_result\")\;\n";
    print OUTFILE "attach(arc3_data)\;\n";
    print OUTFILE "png(\'arc3_hist_analysis.$sid.png\')\;\n";
    print OUTFILE "hist(V2, col=\"azure3\", main=\"Distribution of Age\", xlab=\"Age\", ylab=)\;\n";
    print OUTFILE "dev.off()\;\n";
    close OUTFILE;
    
    # utilizes R to generate plot
    `R --no-save < /home/gcerqueira/local/apache2/htdocs/templates/casa/results/$R_script_file`;
    
    `cp /home/gcerqueira/local/apache2/cgi-bin/casa/arc3_hist_analysis.$sid.png /home/gcerqueira/local/apache2/htdocs/templates/casa/results/arc3_hist_analysis.$sid.png`; 
    
    
    $dbh->disconnect();
    
		
	 	# Defining the core of the home page
		my $vars = {
			core  			  => 'R_image_page',
			tab_state 		=> 'Query',
			dump 					=> $dump			
		};
		
		return ( $vars ); 
	}
	);

