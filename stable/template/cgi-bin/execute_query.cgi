#!/usr/bin/env perl

use casa_constants;
use strict;
use template_code;
use DatabaseSpecificBackEnd;
use VCFUtils;
use DBI;

TemplateCode::execute(
	sub {
		my ($cgi,$upload_dir) =  @_;
		
		my @results_table;
		my $dump;
		
		my $params     = $cgi->Vars;
		
		my $query;
		
		my ($dbh, $sth);
		
		######################################################
		# Additional parameters	
		my $query                 = $params->{query};
		my $query_count           = $params->{query_count};
		my $num_records           = $params->{num_records};
		my $limit                 = $params->{limit};
		my $previous 		  				= $params->{previous};
		my $next 	   	  					= $params->{next};    
		my $rows = 5;
		
		
		# If the user requested next page
		if($limit != 0 and defined($previous) ){
			$limit -= $rows; 
			
			# If the user requested previous page
		}	elsif(defined($next)){
			$limit += $rows;
			
			# If first query into DB
		}	else {
			$limit = 0; 
		}
		
		
		#connects to databse
		$dbh = DBI->connect($CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD) or die "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n" . DBI->errstr;
	
	
	    # If this is NOT the first page shown a results table
        if( defined( $query ) ){
                $query =~ s/ limit \d+ offset \d+/ limit $rows offset $limit/;
        
        # If the first shown page of a results table
        }else{
        	my $select_from = DatabaseSpecificBackEnd::generate_select_from();
			my $where       = DatabaseSpecificBackEnd::generate_where( $params );
			my $order_by    = DatabaseSpecificBackEnd::generate_order_by();
			$query = "$select_from $where $order_by limit $rows offset $limit;";
						
						
			#execute query to count the number of records
			
			$query_count = "select count(*) from " . $CASA::DB_TABLE . " $where;";
			$sth = $dbh->prepare($query_count);
			$sth->execute() or die "Can't execute SQL statement:\n$query_count\n", $sth->errstr(), "\n";
			($num_records) = $sth->fetchrow_array();
			
			
			#$num_records = 200;
			die "Problem in fetchrow_array(): ", $sth->errstr(), "\n" if $sth->err();
						     	
        }
		
		$dump .= $query . "<BR>";
		
		#execute query
		$sth = $dbh->prepare($query);
		$sth->execute() or die "Can't execute SQL statement:\n$query\n ", $sth->errstr(), "\n";;
		
		my @nt_grid;
		while ( my @row_array = $sth->fetchrow_array() ) {
			push @results_table, @row_array;  
			push @nt_grid, [ @row_array ]; 
		}
		die "Problem in fetchrow_array(): ", $sth->errstr(), "\n" if $sth->err();
		
		
		# NT GRID
		my $nt_grid_html = VCFUtils::color_nt_array( \@nt_grid, 2, 0, \@DatabaseSpecificBackEnd::NT_GRID_COLS, \@DatabaseSpecificBackEnd::NT_GRID_HEADER);
		
		# Columns that the user selected as NO SHOW (in the query page)
		my $do_not_show = $params->{do_not_show};
		$do_not_show =~ s/\0//g;

		my $do_not_show_str = $do_not_show;
		$do_not_show_str =~ s/%/,/g;
		$do_not_show_str =~ s/,$//g;
		
		
		$dbh->disconnect();
		
		my $core;
		$core = 'query_results';
		
		
	 	# Defining the core of the home page
		my $vars = {
			core  				=> $core,
			tab_state 			=> 'Query',
			results_table       		=> \@results_table,
			nt_grid_html        		=> $nt_grid_html,
			do_not_show			=> $do_not_show,
			do_not_show_str			=> $do_not_show_str,			
			query   			=> $query,
			query_count			=> $query_count,
			num_records			=> $num_records,
			limit   			=> $limit,
			previous 			=> $previous,
			next	   			=> $next,
			rows	   			=> $rows,
			dump 				=> $dump,
			R_ANALYSIS    			=> $CASA::R_ANALYSIS
		};
		
		return ( $vars ); 
	}
	);

