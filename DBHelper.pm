package DBHelper;
use strict;
use IPCHelper;

sub upload_into_db{
	my ( $dbh, $query, $line_num, $line ) = @_;
	my $sth = $dbh->prepare($query);
	$sth->execute() or die "Error on line $line_num:\n\t$line\n\nCan't execute SQL statement: ", $sth->errstr(), "\n";
}

# Deprecated DO NOT USE it anymore
sub executeFilePsql{
	my ( $file, $database, $user, $postgres_dir, $task_name, $logfile ) = @_;
	my $postgres_bin = $postgres_dir . '/psql';

	my $log = Log::Log4perl->get_logger();	

	my $progress_eta = `wc $file | awk '{print $1}'`;
	chomp( $progress_eta );
	
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


#sub executeFileMysql{
#	my ( $file, $database, $user, $task_name, $logfile ) = @_;
#	my $postgres_bin = $postgres_dir . '/psql';
#
#	my $log = Log::Log4perl->get_logger();	
#
#	my $progress_eta = `wc $file | awk '{print $1}'`;
#	chomp( $progress_eta );
#	
#	if( defined $logfile ){
#		IPCHelper::RunSQLCmdList( [ 'cat', 
#			$file,
#			'|',
#			$postgres_bin,
#			$database,
#			'-U',
#			$user,
#			'&>',
#			$logfile ], 
#			"Unable to execute PostgreSQL commands in file: " . $file . "\n\tUsing the PostgreSQL binaries at $postgres_bin", $task_name, $progress_eta );	
#	}else{
#		IPCHelper::RunSQLCmdList( [ 'cat', 
#			$file,
#			'|',
#			$postgres_bin,
#			$database,
#			'-U',
#			$user ], 
#			"Unable to execute PostgreSQL commands in file: " . $file . "\n\tUsing the PostgreSQL binaries at $postgres_bin", $task_name, $progress_eta );	
#		
#		
#	}
#}


sub executeCmdPsql{
	my ( $cmd, $database, $user, $postgres_dir, $logfile ) = @_;
	my $postgres_bin = $postgres_dir . '/psql';
	
	
	if( defined $logfile ){
		IPCHelper::RunSQLCmdList( [ 'echo', 
			"\'$cmd\'",
			'|',
			$postgres_bin,
			$database,
			'-U',
			$user,
			'&>',
			$logfile ], 
			"Unable to execute PostgreSQL command\n\t$cmd\n\tUsing the PostgreSQL binaries at $postgres_bin", 1 );	
	}else{
		IPCHelper::RunSQLCmdList( [ 'echo', 
			"\'$cmd\'",
			'|',
			$postgres_bin,
			$database,
			'-U',
			$user ], 
			"Unable to execute PostgreSQL command\n\t$cmd\n\tUsing the PostgreSQL binaries at $postgres_bin", 1 );	
		
		
	}
}


return 1;
