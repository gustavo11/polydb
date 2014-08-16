#!/usr/bin/env perl


# Add polydb_home to installer config instead of polydb_template
# Add to installer user and pass to Postgres


use FindBin;
use lib "$FindBin::Bin";
use File::System;
use Carp;
#use Carp::Always;
use Pod::Usage;
use Getopt::Long;
use TestPostgreSQL;

use strict;


=head1 NAME
polydb_generate_host_specific_config_file.pl


=head1 SYNOPSIS
generate_host_specific_config.pl [--file_prefix <output file prefix> ] [--help ]


=head1 DESCRIPTION

This script attempts to either guess host specific properties or request from the user the respective information.  
It saves the gathered information in the file <prefix given as parameter>.host_specific_configuration.conf.
The hostname will be used as prefix if a command parameter is not given.


*********************
* A T T E N T I O N *
*********************

This script needs to be executed on the server
hosting the web server and PostgreSQL database!!

=head1 AUTHOR
Gustavo C. Cerqueira (2013)

We love our customers!

d88b.d88b,
88888888888
`Y8888888Y'
`Y888Y'
`Y'

=cut


####################
# Constants



my $debug = 0;


if( $debug == 1 ){
	$Carp::Verbose = 1;
}

#####################
my $file_prefix;
my $help;

GetOptions(	'file_prefix:s'			=> \$file_prefix,
	'help'	 			=> \$help );


pod2usage(-verbose => 2 ,-exitval => 2) if defined $help; 

if( not defined($file_prefix) ){
	# Set file prefix as the hostname 
} 


#######################################################
# Directory containing PostgreSQL binaries

my $psql_bin_dir;
$psql_bin_dir = `ps x | grep postgres | grep -v 'postgres:' | grep -v 'grep' | awk '{print \$5}' | sed 's/postgres//' | grep -v 'sed'`;
chomp $psql_bin_dir;

if( ! -e "$psql_bin_dir/psql" ){
	print "Unable to guess directory containing PostgreSQL binaries!\n";
}

while( 	! -e "$psql_bin_dir/psql" ){
	print "Where PostreSQL binaries are located?\n";
	$psql_bin_dir = <>;
	chomp $psql_bin_dir;
	
	if( ! -d $psql_bin_dir ){					
		print "The directory \'$psql_bin_dir\' does NOT exist!!\n";
	}else{
		print "PostgreSQL client ('psql') not found in the directory \'$psql_bin_dir\'.\n";
		print "Path doesn't doesn't seem to be correct!\n";
	}
}	


print "PostgreSQL binaries found on: \'$psql_bin_dir\'\n";



#######################################################
# Port PostgreSQL is listening to
my $psql_port = 5432;
my $psql_database_user = getpwuid($>);


my $connection_result = TestPostgreSQL::testConnection( 'localhost', $psql_port, 'postgres', $psql_database_user ); 

if(  $connection_result eq 'NO_CONNECTION' ){
	$psql_port = 5433;	
	if( TestPostgreSQL::testConnection( 'localhost', $psql_port, 'postgres', $psql_database_user ) eq 'NO_CONNECTION' ){
			print "Unable to connect to PostgreSQL server on localhost using either port 5432 or 5433!\n";
	}
}elsif( $connection_result eq 'UNKNOWN ERROR' ){
	die;
}


while( 	$connection_result eq 'NO_CONNECTION' ){
	print "What port PostreSQL is listening to?\n";
	$psql_port = <>;
	chomp $psql_port;

	$connection_result = TestPostgreSQL::testConnection( 'localhost', $psql_port, 'postgres', $psql_database_user );
	
	if( $connection_result eq 'NO_CONNECTION' ){					
		print "Unable to connect to PostgreSQL server on localhost using port $psql_port!\n";
	}
}	

print "PostgreSQL port: \'$psql_port\'\n";


#######################################################
# Password of the user listed above
print "What is the password associated to the current user on PostreSQL?\n";
my $psql_database_password = <>;


#######################################################
# Test if current user can create databases
# if so create PolyDB database

my $connection_result = TestPostgreSQL::testConnection( 'localhost', $psql_port, 'postgres', $psql_database_user, $psql_database_password ); 



#######################################################
# User executing this script.
# this user should also have create table, modify table privileges in PostgreSQL database referred above

$connection_result = TestPostgreSQL::testConnection( 'localhost', $psql_port, 'postgres', $psql_database_user ); 

while( 	$connection_result eq 'USER_NOT_FOUND' ){
	print "What PostreSQL is listening to?\n";
	$psql_port = <>;
	chomp $psql_port;
	
	if( TestPostgreSQL::testConnection( 'localhost', $psql_port, 'postgres', $psql_database_user ) eq 'NO_CONNECTION' ){					
		print "Unable to connect to PostgreSQL server on localhost using port $psql_port!\n";
	}
}	

print "PostgreSQL user: \'$psql_database_user\'\n";



# Name of PostgreSQL database storing PolyDB tables
my $psql_database_name = 'polydb';




# Apache user name, usually www-data. I need this info so I can transfer the privileges
# to the Apache user and then the web-front end can access PolyDB database
my $apache_user = 'www-data';

# Subdirectory of Apache HTDOCS directory where PolyDB home pages will reside
my $html_base = '/seq/gscidA/www-public/htdocs/polydb';

# Host
my $host = 'timneh.broadinstitute.org';

# URL of polydb web pages
my $url = 'timneh.broadinstitute.org/polydb';

# Directory containing the perl libraries
# If using local::libs to install libraries in the home directory
# then this variable should be equal to:
# <home dir>/perl5/lib/perl5
# perl_lib = 

# Directory containing Vcf.pm file, part of VCF tools
my $vcf_pm_dir = '/seq/aspergillus1/gustavo/usr/local/vcftools_0.1.8a/lib/perl5/site_perl';

# Location of cgi-bin directory
# Leave it empty if cgi-bin can be internal to DocumentRoot (htdocs); 
# If cgi-bin directory is outside DocumentRoot (htdocs), provide here the full path, usually in /usr/lib/cgi-bin
my $cgibin_root = '/usr/lib/cgi-bin';




my $out = <<TEXT_OUT;
#############################
# Host dependent variables

# Directory containing PostgreSQL binaries
psql_bin_dir = /seq/gscidA/www-public/htdocs/polydb/psql/bin

# Port PostgreSQL is listening to
psql_port = 5433

# Name of PostgreSQL database storing PolyDB tables
psql_database_name = polydb

# User executing this script.
# this user should also have create table, modify table privileges in PostgreSQL database referred above
psql_database_user = gustavo

# Password of the user listed above
psql_database_password = livotica

# Apache user name, usually www-data. I need this info so I can transfer the privileges
# to the Apache user and then the web-front end can access PolyDB database
apache_user = www-data

# Subdirectory of Apache HTDOCS directory where PolyDB home pages will reside
html_base = /seq/gscidA/www-public/htdocs/polydb

# Host
host = timneh.broadinstitute.org

# URL of polydb web pages
url = timneh.broadinstitute.org/polydb

# Directory containing the perl libraries
# If using local::libs to install libraries in the home directory
# then this variable should be equal to:
# <home dir>/perl5/lib/perl5
# perl_lib = 

# Directory containing Vcf.pm file, part of VCF tools
vcf_pm_dir = /seq/aspergillus1/gustavo/usr/local/vcftools_0.1.8a/lib/perl5/site_perl

# Location of cgi-bin directory
# Leave it empty if cgi-bin can be internal to DocumentRoot (htdocs); 
# If cgi-bin directory is outside DocumentRoot (htdocs), provide here the full path, usually in /usr/lib/cgi-bin
cgibin_root = /usr/lib/cgi-bin
TEXT_OUT






exit(0);





