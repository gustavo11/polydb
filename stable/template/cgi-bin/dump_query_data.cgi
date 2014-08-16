#!/usr/bin/env perl
use casa_constants;
use DatabaseSpecificBackEnd;
use template_code;
use DBI;
use strict;

TemplateCode::execute(
	sub {
		my ( $cgi, $upload_dir ) = @_;

		my @results_table;

		my $query = $cgi->param("query");

		my $num_records = $cgi->param("num_records");

		my $dump = $query . "<BR>";
		my $sid  = $cgi->param("SID");

		my $dumpFilePrefix = "dump";
		my $dumpFilePath   = $CASA::TEMPLATE_DIR . "/results";

		my $txtFileName = "$dumpFilePath/$dumpFilePrefix.$sid.txt";
		my $zipFileName = "$dumpFilePath/$dumpFilePrefix.$sid.zip";

		# MySQL
		#$query =~ s/ limit \d+,\d+/;/;

		# Postgres
		$query =~ s/ limit \d+ offset \d+//;

		my ($where) = ( $query =~ /(where [\w\W]+)/ );

		my $select = DatabaseSpecificBackEnd::generate_dump_select_from();

		$query = "$select $where;";

		# If the number of records > 10,000 than fork this process
		# and send to the browser indicating that the downloadable file
		# will take sometime

		if ( $num_records > 10000 ) {

			my $pid = fork();

			if ( not defined $pid ) {
				print "Resources not available\n";
			}

			# If this is the CHILD
			# then generate the dowloadable file
			elsif ( $pid == 0 ) {
				print STDERR ">>>>> Dumping delayed\n";
				close STDOUT;
				generate_zip_file( $query, $txtFileName, $zipFileName );
				exit(0);

				# If this is the PARENT
				# then send to the browser page indicating that it will take
				# sometime to prepare the downloadable file
			}
			else {

				# Defining the core of the home page
				my $vars = {
					core        => 'link_to_delayed_dump',
					progress    => 0,
					num_records => $num_records,
					tab_state => 'Query',
					zipfile            => "$dumpFilePrefix.$sid.zip",
					URL_base_dump_file => $CASA::URL_base_dump_file,
					dump               => $dump
				};

				return ($vars);

			}

		}
		else {
			generate_zip_file( $query, $txtFileName, $zipFileName );

			# Defining the core of the home page
			my $vars = {
				core               => 'link_to_dump',
				tab_state          => 'Query',
				zipfile            => "$dumpFilePrefix.$sid.zip",
				URL_base_dump_file => $CASA::URL_base_dump_file,
				dump               => $dump
			};

			return ($vars);

		}

	}
);

sub generate_zip_file {
	my ( $query, $txtFileName, $zipFileName ) = @_;

	`rm $zipFileName.done`;

	open( OUTFILE, ">", "$txtFileName" )
	  || die("Unable to write file $txtFileName. $!\n");

	my ( $dbh, $sth );

	#connects to databse
	$dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD )
	  or die
"Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n"
	  . DBI->errstr;

	#execute query
	$sth = $dbh->prepare($query);
	$sth->execute();

	# Adding header to dump file
	print OUTFILE "$DatabaseSpecificBackEnd::DUMP_FILE_HEADER";

	while ( my @row_array = $sth->fetchrow_array() ) {
		foreach my $field (@row_array) {
			print OUTFILE $field . "\t";
		}
		print OUTFILE "\n";
	}
	close OUTFILE;

	`rm $zipFileName`;
	`zip -j $zipFileName $txtFileName`;
	`touch $zipFileName.done`;

	$dbh->disconnect();

}
