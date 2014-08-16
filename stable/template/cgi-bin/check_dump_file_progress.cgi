#!/usr/bin/env perl
use strict;
use DatabaseSpecificBackEnd;
use template_code;
use DBI;

TemplateCode::execute(
	sub {
		my ( $cgi, $upload_dir ) = @_;

		my $num_records = $cgi->param("num_records");
		my $sid  = $cgi->param("SID");

		my $dumpFilePrefix = "dump";
		my $dumpFilePath   = $CASA::TEMPLATE_DIR . "/results";

		my $txtFileName = "$dumpFilePath/$dumpFilePrefix.$sid.txt";
		my $zipFileName = "$dumpFilePath/$dumpFilePrefix.$sid.zip";
		my $doneFile    = "$zipFileName.done";

		my $lines = `wc $txtFileName | awk '{print $1}'`;
		
		my $progress = int( $lines / $num_records * 100 );
		
		my $done = (-e $doneFile); 
		
		my $dump = "Progress: $progress <BR>";
		$dump   .= "DONE: $done <BR>";
		

        # IF DONE, then load the page with the link to the downloadable file
		if ( $done ) {

			# Defining the core of the home page
			my $vars = {
				core               => 'link_to_dump',
				tab_state          => 'Query',
				zipfile            => "$dumpFilePrefix.$sid.zip",
				URL_base_dump_file => $CASA::URL_base_dump_file,
				dump               => $dump
			};

			return ($vars);
		
		# IF NOT DONE, reload the progress page
		}else{

				# Defining the core of the home page
				my $vars = {
					core               => 'link_to_delayed_dump',
  					num_records        => $num_records,				
  					progress           => $progress,				
					tab_state          => 'Query',
					URL_base_dump_file => $CASA::URL_base_dump_file,
					dump               => $dump
				};

				return ($vars);


		}
	}
);
