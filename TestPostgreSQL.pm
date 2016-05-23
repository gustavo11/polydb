package TestPostgreSQL;

use DBI;


sub testConnection{
	my ($host,$port,$db,$user,$password) = @_;
	
	my $dsn = "dbi:Pg:db=$db;host=$host;port=$port;";	
	
	if( not DBI->connect( $dsn, $user, $password, {'PrintError'=>0} ) ){
		return 'USER_NOT_FOUND' if DBI->errstr =~ 'role' &&  DBI->errstr =~ 'does not exist';
		return 'NO_CONNECTION' if DBI->errstr =~ 'could not connect to server';
		
		print DBI->errstr;
		return 'UNKNOWN ERROR'; 		
	}else{
		return "SUCCESS";
	}
}

return 1;
