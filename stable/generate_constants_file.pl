#!/usr/bin/env perl

use lib $ENV{vcf_pm_dir};

use Data::Dumper;
use strict;
use IO::Handle;
use Getopt::Long;
use Carp;


STDOUT->autoflush(1);

my $usage = "\ngenerate_contants_file.pl \n" . 
            "\t--polydb_home < full path to directory containing polydb installation > \n" .
            "\t--perl_lib < directory containing perl libraries > \n" .
            "\t--species <species full name. Ex.: Candida albicans > \n" .
	    "\t--db_string <host:port:db_name:user:password  Ex. localhost:polydb:gustavo:livotica > \n" .
	    "\t--table_name <table name. Ex.: calbicans (use only lower case letters and numbers) > \n" .            
	    "\t--host. Host and port, port is optional. Ex.: timneh.broadinstitute.org:8080  > \n" .
	    "\t--url <url base and port (port optional). Ex.: timneh.broadinstitute.org:8080/polydb  > \n" .
	    "\t--htdocs_base <htdocs base. Ex.: /seq/gscidA/www-public/htdocs/polydb > \n" .
	    "\t--cgibin_internal_htdocs. This is a flag indicating that cgi-bin (Script is internal to htdocs\n".
	    "\t\t If thats not the case, for example, if cgi-bin is a subdirectory of /usr/lib, than please ommit this flag\n" . 
	    "\t--out <output file> \n" .
            "\t[--locus_id_ex<locus id example. Ex.: orf19.6115 >]\n\n";

    
    
####################
# Parameter parsing

my $p_polydb_home;
my $p_perl_lib;
my $p_species_full_name;
my $p_db_string;
my $p_table_name;
my $p_host;
my $p_url_base;
my $p_htdocs_base;
my $p_cgibin_internal_htdocs;
my $p_out;
my $p_locus_id_example;

GetOptions(	'polydb_home=s'			=> \$p_polydb_home,
		'perl_lib=s'			=> \$p_perl_lib,
		'species=s'			=> \$p_species_full_name,
		'db_string=s' 			=> \$p_db_string,
		'table_name=s'	 		=> \$p_table_name,
		'host=s'			=> \$p_host,		
		'url=s'				=> \$p_url_base,
		'htdocs_base=s'			=> \$p_htdocs_base, 
		'cgibin_internal_htdocs'	=> \$p_cgibin_internal_htdocs,
		'out=s'				=> \$p_out, 
		'locus_id_ex:s'			=> \$p_locus_id_example 
		
		
);



if( not defined($p_polydb_home) ){
	print STDERR "--polydb_home parameter is required!\n\n";
	die $usage;	
}

if( not defined($p_perl_lib) ){
	print STDERR "--perl_lib parameter is required!\n\n";
	die $usage;	
}


if( not defined($p_species_full_name) ){
	print STDERR "--species parameter is required!\n\n";
	die $usage;	
}

if( not defined($p_db_string) ){
	print STDERR "--db_string parameter is required!\n\n";
	die $usage;	
}

if( not defined($p_table_name) ){
	print STDERR "--table_name parameter is required!\n\n";
	die $usage;	
}

if( not defined($p_host) ){
	print STDERR "--host parameter is required!\n\n";
	die $usage;	
}

if( not defined($p_url_base) ){
	print STDERR "--url parameter is required!\n\n";
	die $usage;	
}

if( not defined($p_htdocs_base) ){
	print STDERR "--htdocs_base parameter is required!\n\n";
	die $usage;	
}

if( not defined($p_out) ){
	print STDERR "--out parameter is required!\n\n";
	die $usage;	
}


#my ( $p_db_host, $p_db_port, $p_db_name, $p_db_user, $p_db_password ) = split ":", $p_db_string;
my ( $p_db_host, $p_db_port, $p_db_name, $p_db_user ) = split ":", $p_db_string;

my $p_table_name_sorted = $p_table_name . "_sorted";


my $DSN = 'dbi:Pg:db=$DB;';

if( $p_db_host ne '' ){
   $DSN .= 'host=$DB_SERVER;';
}
	
if( $p_db_port ne '' ){
   $DSN .= 'port=$DB_PORT;';
}
	
$p_species_full_name =~ s/^\'//;
$p_species_full_name =~ s/^\"//;
$p_species_full_name =~ s/\'$//;
$p_species_full_name =~ s/\"$//;


# Adjusting cgi-bin URL based on the parameter $p_cgibin_internal_htdocs
my $cgibin_url;
if( $p_cgibin_internal_htdocs ){
 $cgibin_url = "$p_url_base/$p_table_name/cgi-bin";
}else{
 $cgibin_url = "$p_host/cgi-bin/polydb/$p_table_name";
}

my $out = <<STR_OUT;
package CASA;

use lib '$p_polydb_home';
use lib '$p_perl_lib';

\$ORG_DIR = "$p_table_name"; # Example: "c.albicans"
\$SPECIES = "$p_species_full_name"; # Example: "Candida albicans";
\$EXAMPLE_LOCUS_ID = "$p_locus_id_example";

\$HTDOCS			= "$p_htdocs_base/\$ORG_DIR";
\$TEMPLATE_DIR 			= "\$HTDOCS";
\$WEB_SERVER_AND_PORT		= "$p_url_base/\$ORG_DIR";
\$GENOMEVIEW_URL   		= "$p_url_base/\$ORG_DIR/genomeview";

\$URL_base_dump_file = "http://\$WEB_SERVER_AND_PORT/results";
\$URL_base_CGI       = "http://$cgibin_url";
\$CGI_BASE_DIR       = "http://$cgibin_url";
\$CSS_BASE_DIR       = "http://\$WEB_SERVER_AND_PORT/css";

# Database 
\$DB			= "$p_db_name";
\$DB_SERVER 		= "$p_db_host";
\$DB_PORT 		= "$p_db_port";
\$DSN			= "$DSN";
\$DB_USER 		= "$p_db_user";
\$DB_PASSWORD 		= "";
\$DB_TABLE 		= "$p_table_name_sorted"; # Example: "candida_sorted" 
		
# Calls to R statistics package will be allowed (1) or not (0)
\$R_ANALYSIS 	= 1;

# Links to db schema and site map will be shown (1) or not (0)
\$DB_SITE_INFO = 1; 

return 1;

STR_OUT

open OUT, ">$p_out" or croak "Unable to write file \'$p_out\'\n";
print OUT $out;
close(OUT);
