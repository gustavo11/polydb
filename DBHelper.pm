package DBHelper;
use strict;
use IPCHelper;
use DBI;

sub upload_into_db{
	my ( $dbh, $query, $line_num, $line ) = @_;
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
}

sub executeFilePsql{
	my ( $file, $database, $user, $postgres_dir, $task_name, $logfile ) = @_;
	my $postgres_bin = 'psql';
	$postgres_bin = $postgres_dir . '/psql' if $postgres_dir ne ''; 

	my $log = Log::Log4perl->get_logger();	

	# The estimate time is based on the number of lines in the VCF
	# The routine below count the number of lines in the VCF
	my $progress_eta = 0;
	open(FILE, "$file") or $log->fatal("Unable to open file $file!");
	$progress_eta++ while <FILE>;
	close(FILE);

	
	if( defined $logfile ){
		IPCHelper::RunSQLCmdList( [ 'cat', 
			$file,
			'|',
			$postgres_bin,
			$database,
			'-U',
			$user,
			'&>',
			$logfile ], 
			"Unable to execute PostgreSQL commands in file: " . $file . "\n\tUsing the PostgreSQL binaries at $postgres_bin", $task_name, $progress_eta );	
	}else{
		IPCHelper::RunSQLCmdList( [ 'cat', 
			$file,
			'|',
			$postgres_bin,
			$database,
			'-U',
			$user ], 
			"Unable to execute PostgreSQL commands in file: " . $file . "\n\tUsing the PostgreSQL binaries at $postgres_bin", $task_name, $progress_eta );	
		
		
	}
}




sub executeCmdPsql{
	my ( $cmd, $database, $user, $postgres_dir, $logfile ) = @_;
	my $postgres_bin = 'psql';
	$postgres_bin = $postgres_dir . '/psql' if $postgres_dir ne ''; 
	
	if( defined $logfile ){
		IPCHelper::RunCmd( [ 
			$postgres_bin,
			'-c',
			$cmd,
			$database,
			'-U',
			$user,
			'&>',
			$logfile ], 
			"Unable to execute PostgreSQL command\n\t$cmd\n\tUsing the PostgreSQL binaries at $postgres_bin", 1 );	
	}else{
		IPCHelper::RunCmd( [ 
			$postgres_bin,
			'-c',
			$cmd,
			$database,
			'-U',
			$user ], 
			"Unable to execute PostgreSQL command\n\t$cmd\n\tUsing the PostgreSQL binaries at $postgres_bin", 1 );	
		
		
	}
}



return 1;
