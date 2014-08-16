#!/usr/bin/env perl

# Todo:
# It sounds really stupid, but the library that Im using to validate the configuration file variables is not accepting 
# an extra space in the dataset name. You have an extra space in the end of the dataset name.
# I will fix this, but please for the time being remove any extra space in the end of variables in the configuration file.
# I will also turn off error dump so you can better see the error description. 
# progress bar when inserting and updaiting the db
# progress file allowing the script to start from where was halted

# Introduce a switch that allow the keeping of all homogeneous sites

# use DBHelper;

# Add polydb_home to installer config instead of polydb_template
# Add to installer user and pass to Postgres

use strict;

use FindBin;
use lib "$FindBin::Bin";
use Parse::PlainConfig;
use Config::Validate;
use IPC::Run;
use File::System;
use IPCHelper;
use DBHelper;
use Carp;
#use Carp::Always;
use Pod::Usage;
use Getopt::Long;
use Log::Log4perl;
use DBI;
use VCFDB;


=head1 NAME

polydb_installer.pl

=head1 SYNOPSIS

polydb_generate_web_app.pl --config <configuration file> 
--host-specific-config <host specific configuration file> [--skip_warning] [--help]
[ --jump_to <COPY_TEMPLATE_FILES | INSERT_RECORDS | UPDATE_RECORDS | ANNOTATE_VCF | SORT_TABLE | POST_PROCESS_DB | CHECKING_DB | CREATING_WEB_FRONT_END | PREPARING_GENOME_VIEW | FINAL_ARRANGEMENTS > ]


=head1 DESCRIPTION

Creates an instance of PolyDB from a set VCF files listed in a PolyDB configuration file.
A sample configuration file is available at:

<POLYDB HOME DIR>/template_generate_web_app.conf
 
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
my $IPC_verbose = $debug;


if( $debug == 1 ){
	$Carp::Verbose = 1;
}

my $running_at_broad = 1;
my $upload_full_annotation = 0;

#####################
# Global variables

my $cmd;
my $arg1;
my $arg2; 
my $path;
my $path2;
my $cmdRef;	
my $full_cmd;


####################
# Parameter parsing

my $config_file;
my $skip_warning;
my $jump_to;
my $help;

GetOptions(	'config=s'			=> \$config_file,
		'skip_warning' 			=> \$skip_warning,
		'help'	 			=> \$help,
		'jump_to:s'			=> \$jump_to );
		

pod2usage(-verbose => 2 ,-exitval => 2) if defined $help; 

if( not defined($config_file) ){
   print STDERR "Parameter --config is required\n\n";  
   pod2usage(-verbose => 1 ,-exitval => 2);
} 

if( defined $jump_to &&
      ( $jump_to ne 'COPY_TEMPLATE_FILES' &&
      	$jump_to ne 'INSERT_RECORDS' &&
      	$jump_to ne 'UPDATE_RECORDS' &&
      	$jump_to ne 'ANNOTATE_VCF' &&
      	$jump_to ne 'SORT_TABLE' &&
      	$jump_to ne 'POST_PROCESS_DB' && 
   	$jump_to ne 'CHECKING_DB' &&
   	$jump_to ne 'CREATING_WEB_FRONT_END' &&
   	$jump_to ne 'PREPARING_GENOME_VIEW' &&
   	$jump_to ne 'FINAL_ARRANGEMENTS') ){

    print STDERR "Parameter --jump_to should be either:" .
   	   	"COPY_TEMPLATE_FILES OR\n" .
   		"INSERT_RECORDS OR\n" .
   		"UPDATE_RECORDS OR\n" .
   		"ANNOTATE_VCF OR\n" .
   		"SORT_TABLE\n" .
   		"POST_PROCESS_DB\n" .
   		"CHECKING_DB\n" .
   		"CREATING_WEB_FRONT_END\n" .
   		"PREPARING_GENOME_VIEW\n" .
   		"FINAL_ARRANGEMENTS\n\n";
   	  
   pod2usage(-verbose => 1 ,-exitval => 2);
} 



##############################
# Config file parsing


my $conf = new Parse::PlainConfig;
my $conf = Parse::PlainConfig->new(
	'PARAM_DELIM'  => '=',
	'MAX_BYTES'    => 65536,
	'SMART_PARSER' => 1,
	);



# Read config file
my $rv = $conf->read( $config_file );
die Parse::PlainConfig::ERROR if $rv == 0;

# Store all the data structure of config file
# in the hash ref $config
my $config = $conf->get_ref();


my $schema = {
	#############################
	# Host dependent variables
	
	psql_bin_dir => {
		type    => 'directory',
		default => '/seq/gscidA/www-public/htdocs/polydb/psql/bin',
	},
	
	
	psql_port => {
		type    => 'integer',
		default => 5432	
	},
	
	
	psql_database_name => {
		type    => 'string',
		default => 'polydb',
		
		# Only lower case letters
		regex => '^[a-z_0-9]+$'
	},
	
	psql_database_user => {
		type    => 'string',
		default => 'gustavo',
	},
	
	psql_database_password => {
		type    => 'string',
		default => 'livotica',
	},
	
	##############################
	# Dataset/Organism specific variables
	
	dataset_name => {
		type => 'string',
		
		# Only lower case letters
		# Less than 10 characters.
		# Dataset with more than 10 characters will generate some issues when
		# creating indexed fields names. Those names are going to be very large
		# because they encompass the concatenation of the "dataset name" and 
		# the "field name" 		
		regex => '^[a-z_0-9]{1,16}$'
	},
	
	# Species. Example: Mycoplasma tuberculosis
	species => { type => 'string' },
	
	
	# Species abbreviation. Example: m.tuberculosis
	#species_abbreviation => { 
	#	type => 'string'
	#},
	
	vcf_list => { type => 'file' },
	
	vcf_list_annot => { type => 'file' },

	# Apache user name, usually www-data. I need this info so I can transfer the privileges
	# to the Apache user and then the web-fron end can access polydb database
	apache_user => {
		type    => 'string',
		default => 'www-data',
	},
	
	html_base => {
		type => 'string',		
		default => '/seq/gscidA/www-public/htdocs/polydb'
	},

	# Location of cgi-bin directory
	# Leave it empty if cgi-bin can be internal to DocumentRoot (htdocs); 
	# If cgi-bin directory is outside DocumentRoot (htdocs), provide here the full path, usually in /usr/lib/cgi-bin
	
	cgibin_root => {
		type => 'string',
		default => ''		
	},
	

	host => {
		type    => 'string',
		default => 'timneh.broadinstitute.org'
		
	},

	
	url => {
		type    => 'string',
		default => 'timneh.broadinstitute.org/polydb'
		
	},

	perl_lib => {
		type => 'string',		
	},
	
	vcf_pm_dir => {
		type => 'string',		
		default => '/seq/aspergillus1/gustavo/usr/local/vcftools_0.1.8a/lib/perl5/site_perl'
	},
	
	
	
	#######################################################
	# Variables that change the way the data is imported
	
	keep_homogeneous_sites => {
		type    => 'integer',
		default => 0
		
	},
	
	
	############################################
	# Variables used on Genomeview configuration
	
	# Path to FASTA file containing the genomic sequence
	genome_fasta => {
		type     => 'file',
		optional => 1
	},
	
	# Path to GFF3 file describing the genome annotation
	gff => {
		type     => 'file',
		optional => 1
	},
	
	# A list of BAM filenames containing the read alignment against reference genome
	# Format:
	#<Alias to set of reads>\t<full path to theoriginal BAM file. Indexes (*.bai files) should be in the same directory>
	bam_list => {
		type     => 'file',
		optional => 1
	}
};



# Validating config file
my $validate_obj = Config::Validate->new( schema => $schema );
my $hashRef = $validate_obj->validate( config => $config );

my %p = %{$hashRef};

# Storing in this variable the directory containing 
# all PolyDB executable and libraries
my $polydb_home = "$FindBin::Bin";

# Starting logging
#sub getFileMode{ return "write"; };
`rm polydb.log` if( -e 'polydb.log' );
`rm polydb.screen` if( -e 'polydb.screen' );
`rm polydb.debug` if( -e 'polydb.debug' );
Log::Log4perl->init( $polydb_home . '/log4perl.conf' );
my $log = Log::Log4perl->get_logger();

$SIG{__WARN__} = sub {
        local $Log::Log4perl::caller_depth =
            $Log::Log4perl::caller_depth + 1;
        $log->warn( @_ );
};
    
$SIG{__DIE__} = sub {
        if($^S) {
            # We're in an eval {} and don't want log
            # this message but catch it later
            return;
        }
        $Log::Log4perl::caller_depth++;
        $log->logexit( @_ );
};



$log->info("Initializing logging ...");

# Remove trailing slash from all paths

# Adding some additional values to %p hash
$p{polydb_template} = $polydb_home . '/template';
$p{html_root} = $p{html_base} . '/' . $config->{dataset_name};


# Making the access to some variables in the hash easier
my $sorted_dataset = $p{dataset_name} . '_sorted';
my $dataset_name = $p{dataset_name};
my $html_root = $p{html_root};


# Adjusting cgi-bin root 
my $cgibin_root = $p{cgibin_root};
my $cgibin_url;
my $cgibin_internal_htdocs;

if( $cgibin_root eq '' ){
	$cgibin_internal_htdocs = 1;
	$cgibin_root = 	'/seq/gscidA/www-public/htdocs/polydb/'
		. $p{dataset_name}
		. '/cgi-bin';
		
	$cgibin_url = $p{host} . "/" . $p{dataset_name} . "/cgi-bin";
		
}else{
	$cgibin_internal_htdocs = 0;
	$cgibin_root .= '/polydb/'
		. $p{dataset_name};

	$cgibin_url = $p{host} . "/cgi-bin/polydb/" . $p{dataset_name};
}	



if( not defined $skip_warning ){

print STDERR "\n";
print STDERR "*********************\n";
print STDERR "* A T T E N T I O N *\n";
print STDERR "*********************\n";
print STDERR "\n";
print STDERR "This script needs to be executed on the server\n";
print STDERR "hosting the web server and PostgreSQL database!!\n";
print STDERR "If running at Broad Institute, the correct server is timneh.broadinstitute.org\n" if $running_at_broad;
print STDERR "\n";
print STDERR "\n";
print STDERR "*****************\n";
print STDERR "* W A R N I N G *\n";
print STDERR "*****************\n";
print STDERR "\n";
print STDERR "If there is a PolyDB web site previously installed in the directories:\n";
print STDERR "HTML ROOT: " . $p{html_root} . "\n";
print STDERR "CGI-BIN ROOT: " . $cgibin_root . "\n\n";
print STDERR "IT WILL BE OVERWRITTEN !!!!!\n\n\n";
print STDERR "And the tables:\n";
print STDERR "$dataset_name\n";
print STDERR "$sorted_dataset\n\n";
print STDERR "WILL BE DROPPED (DELETED), if they already exist in database '" . $p{psql_database_name} . "'!!!!!\n\n\n";
print STDERR "Hit any key to proceed. Or Ctrl-c to abort\n";
getc();
}

$log->info("HTML ROOT: " . $p{html_root} );
$log->info("CGI-BIN ROOT: " . $cgibin_root);

goto $jump_to if defined $jump_to;


##################################################################
# Copying template files to the new web site
COPY_TEMPLATE_FILES:
$log->info("Copying template files...");

# Creating html_root
$path = $p{html_root};
if( not -d $path ){
	IPCHelper::RunCmd( ['mkdir','-p', $p{html_root}] , "Unable to create <HTML_ROOT> directory: " . $path );
}else{
	$log->debug("HTML ROOT directory, '$path', already exists.");	
}

# Copying htdocs template
$path = $p{polydb_template} . "/htdocs/";
$path2 = $p{html_root}; 
IPCHelper::RunCmd( ['rsync', '-r', '--exclude=.svn', $path, $path2 ] , "Unable to copy template files from $path to directory $path2 " );

# Creating html_root/results
$path = $p{html_root} . "/results";
if( not -d $path ){
	IPCHelper::RunCmd( ['mkdir', $path] , "Unable to create <HTML_ROOT>/results directory: " . $path )
}else{
	$log->debug("<HTML_ROOT>/results directory, '$path', already exists.");	
}

# Change permission html_root/results
$cmd  = "chmod";
$arg1 = "777";
IPCHelper::RunCmd( [$cmd, $arg1, $path ] , "Unable to set read and write permission on $path" );

# Creating cgibin_root
$path = $cgibin_root;
if( not -d $path ){
	IPCHelper::RunCmd( ['mkdir','-p', $path] , "Unable to create cgi-bin root directory: " . $path );
}else{
	$log->debug("cgi-bin root directory, '$path', already exists.");	
}

# Copying cgi-bin template
$path = $p{polydb_template} . "/cgi-bin/";
$path2 = $cgibin_root; 
IPCHelper::RunCmd( ['rsync', '-r', '--exclude=.svn', $path, $path2 ] , "Unable to copy template files from $path to directory $path2 " );


# Generate casa_constants.pm at cgi-bin, for later use by the web-front-end

my $db_string = ":" . $p{psql_port} . ":" . $p{psql_database_name} . ":" . 
	$p{apache_user};


my $cmd  = $polydb_home . "/generate_constants_file.pl";


if( $cgibin_internal_htdocs ){

IPCHelper::SetEnvAndRunCmd( [$cmd, 
			    '--polydb_home', $polydb_home, 	
			    '--perl_lib', $p{perl_lib},
			    '--species', "\"$p{species}\"", 
	                    '--db_string', $db_string, 
	                    '--table_name', $p{dataset_name}, 
	                    '--host', $p{host}, 
	                    '--url', $p{url}, 
	                    '--htdocs_base', $p{html_base},
	                    '--cgibin_internal_htdocs', $cgibin_internal_htdocs,
	                    '--out', $cgibin_root . '/casa_constants.pm' ] , 
	"Unable to generate constants file: " . $cgibin_root . "/generate_constants_file.pl ",
	{ vcf_pm_dir => $p{vcf_pm_dir} }
	);

}else{

	IPCHelper::SetEnvAndRunCmd( [$cmd, 
			    '--polydb_home', $polydb_home, 			
                            '--perl_lib', $p{perl_lib},
			    '--species', "\"$p{species}\"", 
	                    '--db_string', $db_string, 
	                    '--table_name', $p{dataset_name}, 
	                    '--host', $p{host}, 
	                    '--url', $p{url}, 
	                    '--htdocs_base', $p{html_base},
	                    '--out', $cgibin_root . '/casa_constants.pm' ] , 
	"Unable to generate constants file: " . $cgibin_root . "/generate_constants_file.pl ",
	{ vcf_pm_dir => $p{vcf_pm_dir} }
	);

	
}

# Generate casa_constants.pm at the current directory, to be used
# by some of the scripts called here
$db_string = ":" . $p{psql_port} . ":" . $p{psql_database_name} . ":" . 
	$p{psql_database_user} . ":" . $p{psql_database_password};


	IPCHelper::SetEnvAndRunCmd( [$cmd, 
			    '--polydb_home', $polydb_home, 			
                            '--perl_lib', $p{perl_lib},
			    '--species', "\"$p{species}\"", 
	                    '--db_string', $db_string, 
	                    '--table_name', $p{dataset_name}, 
	                    '--host', $p{host}, 
	                    '--url', $p{url}, 
	                    '--htdocs_base', $p{html_base},
	                    '--out', './casa_constants_for_installer.pm' ] , 
	"Unable to generate constants file: ./generate_constants_file.pl ",
	{ vcf_pm_dir => $p{vcf_pm_dir} }
	);



##################################################################
# Populating database
INSERT_RECORDS:
$log->info("Inserting records...");


# Generate files containing SQL commands to create tables, inserts and updates
$cmd  = $polydb_home . "/vcf2sql.pl";

IPCHelper::SetEnvAndRunCmdNoOutBuffer( [$cmd, $p{keep_homogeneous_sites}, $p{vcf_list}, $p{dataset_name} ], 
	"Unable to execute vcf2sql.pl!",
	{ cgibin_root => $cgibin_root, 
	  vcf_pm_dir => $p{vcf_pm_dir} 
	} );

# Creating tables
DBHelper::executeFilePsql( $p{dataset_name} . '_create_tables.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Creating tables' );


# Inserting records
DBHelper::executeFilePsql( $p{dataset_name} . '_inserts.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Inserting records' );

# Vacuum database
#	print "Vacuum database ...\n";
#	IPCHelper::RunCmd( [ $p{psql_bin_dir} . '/vacuumdb', '--analyze', $p{psql_database_name} ] , 
#		'Unable to vacuum database' . $p{psql_database_name} . '!!' );


# Creating indexes
DBHelper::executeFilePsql( $p{dataset_name} . '_ref_based_indexes.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Creating indexes' );

##################################################################
# Updating database with additional fields
UPDATE_RECORDS:
$log->info("Updating records...");

# Updating records
DBHelper::executeFilePsql( $p{dataset_name} . '_updates.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Updating records' );

# Vacuum database
#	print "Vacuum database ...\n";
#	IPCHelper::RunCmd( [ $p{psql_bin_dir} . '/vacuumdb', '--analyze', $p{psql_database_name} ] , 
#		'Unable to vacuum database' . $p{psql_database_name} . '!!' );




#####################################
# Uploading gene annotation fields
ANNOTATE_VCF:
$log->info("Uploading genes annotation...");

$cmd  = $polydb_home . "/brian_annotation_to_sql.pl";

IPCHelper::SetEnvAndRunCmd( [ $cmd, $p{vcf_list_annot}, $p{dataset_name}, 
	$p{dataset_name} . '.annotated.vcf.sql',
	$p{dataset_name} . '.full_annot.sql' ], 
	'Unable to generate SQL commands from annotated VCFs',
	{ cgibin_root => $cgibin_root, vcf_pm_dir => $p{vcf_pm_dir} } );


DBHelper::executeFilePsql( $p{dataset_name} . '.annotated.vcf.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Uploading annotation',
	'error.updating.annotated.vcf.txt' );

# The next step is optional

if( $upload_full_annotation ){
	DBHelper::executeFilePsql( $p{dataset_name} . '.full_annot.sql',  
		$p{psql_database_name}, 
		$p{psql_database_user}, 
		$p{psql_bin_dir}, 'Uploading full annotation',
		'error.updating.full_annot.txt' );
}

# Vacuum database
#	print "Vacuum database ...\n";
#	IPCHelper::RunCmd( [ $p{psql_bin_dir} . '/vacuumdb', '--analyze', $p{psql_database_name} ] , 
#		'Unable to vacuum database' . $p{psql_database_name} . '!!' );




######################
# Create sorted table 
SORT_TABLE:
$log->info("Sorting table...");

DBHelper::executeCmdPsql( "drop table if exists $sorted_dataset;",  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir} );

DBHelper::executeCmdPsql( "create table $sorted_dataset as select * from " . $p{dataset_name} . " order by chrom, position, var_type;",  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir} );

# I have tried, without success, to change the type of the original primary key to serial (id_key)
# So I create another column. This is a good solution, with both columns I can keep track of the order
# of sorted records (id_key_sorted), and the order which the records were uploaded (id_key)

DBHelper::executeCmdPsql( "alter table $sorted_dataset add id_key_sorted SERIAL PRIMARY KEY;",  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir} );


###########################################
# Create the rest of the indexes here

# Regenerate the ref based indexes and constraints
$cmd = "sed 's/ON '$dataset_name'/ON '$sorted_dataset'/g' " . $dataset_name . "_ref_based_indexes.sql " .
	"| sed 's/index '$dataset_name'/index '$sorted_dataset'/' | sed 's/TABLE '$dataset_name'/TABLE '$sorted_dataset'/ '" .
	"| sed 's/unique_coord___'$dataset_name'/unique_coord___'$sorted_dataset'/' > " . $sorted_dataset . "_ref_based_indexes.sql";



IPCHelper::RunCmd( $cmd , "Unable to change index names on file " . $dataset_name . "_ref_based_indexes.sql" );

# Generate new indexes
DBHelper::executeFilePsql( $sorted_dataset . '_ref_based_indexes.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Generating new indexes' );

# Create the sample based indexes
$cmd = "sed 's/ON '$dataset_name'/ON '$sorted_dataset'/g' " . $dataset_name . "_sample_based_indexes.sql " .
	"| sed 's/index '$dataset_name'/index '$sorted_dataset'/'  > " . $sorted_dataset . "_sample_based_indexes.sql";

IPCHelper::RunCmd( $cmd , "Unable to  change index names on file " . $dataset_name . "_sample_based_indexes.sql" );

DBHelper::executeFilePsql( $sorted_dataset . '_sample_based_indexes.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Generating sample based indexes' );


# Vacuum database
#	print "Vacuum database ...\n";
#	IPCHelper::RunCmd( [ $p{psql_bin_dir} . '/vacuumdb', '--analyze', $p{psql_database_name} ] , 
#		'Unable to vacuum database' . $p{psql_database_name} . '!!' );



############################################################
# Post-processing DB
POST_PROCESS_DB:
$log->info("Post-processing...");


IPCHelper::SetEnvAndRunCmd( [ $polydb_home . "/vcf2sql_post_process.pl",
	$sorted_dataset,
	$p{keep_homogeneous_sites},
	"post_process.sql" ], 
	'Unable to generate post-processing SQL commands',
	{ cgibin_root => $cgibin_root, vcf_pm_dir => $p{vcf_pm_dir} },
	);


# Save table before applying post processing
$cmd = $p{psql_bin_dir} . "/pg_dump -o " . $p{psql_database_name} . " -t $sorted_dataset -U " . 
	$p{psql_database_user} . " > $sorted_dataset.before_postprocessing.bak";
IPCHelper::RunCmd( $cmd , 'Unable to backup database before applying post-processing' );


# Applying post-processing
DBHelper::executeFilePsql( 'post_process.sql',  
	$p{psql_database_name}, 
	$p{psql_database_user}, 
	$p{psql_bin_dir}, 'Applying post-processing',
	'error.post_process.txt' );



# In case of something happened... Reverting to the backup
# $psql_dir/psql polydb -U gustavo -c "drop table $sorted_dataset"
# cat $sorted_dataset.before_postprocessing.bak | $psql_dir/psql polydb -U gustavo >& error.restoring





############################################################
# Final check of the DB
CHECKING_DB:
$log->info("Checking database...");

$cmdRef =[ $polydb_home . "/check_db.pl",
	$sorted_dataset,
	$p{vcf_list},
	$p{vcf_list_annot} ];

$full_cmd = join " ", @{$cmdRef};
	
IPC::Run::run( $cmdRef, '>', "check_db.results", 	
	 init => sub { 
	 	 $ENV{cgibin_root} = $cgibin_root; 
	 },
	) or croak "Unable to perform final check on the database\n\tCMD: $full_cmd\n";

`grep "ERROR" check_db.results `;


##################################################################
# Creating HTML interface and sorted table
CREATING_WEB_FRONT_END:
$log->info("Creating web front-end...");

#use R-2.12


# 1st boolean parameter indicates if genomeview infrastructure will be assembled (1) or not (0)
# 2nd boolean parameter if boxplot should be added to the query form (1) or not (0)
# 3rd boolean parameter indicates if one additional column containing full annotation added by
# Brians script should be added to the dump file

IPCHelper::SetEnvAndRunCmd( [ $polydb_home . "/vcf2query.pl",
	$p{vcf_list} ,
	$sorted_dataset,
	0,
	1,
	0 ],
	'Unable to generate database-specific html files for the web front end',
	{ cgibin_root => $cgibin_root, vcf_pm_dir => $p{vcf_pm_dir} },
	$IPC_verbose );


$cmd = "cp " . $sorted_dataset . "_query_database $html_root/DatabaseSpecific_query_database";
IPCHelper::RunCmd( $cmd , "Unable to copy file" );

$cmd = "cp " . $sorted_dataset . "_query_results $html_root/DatabaseSpecific_query_results";
IPCHelper::RunCmd( $cmd , "Unable to copy file"  );

$cmd = "cp " . $sorted_dataset . "_back_end.pm $cgibin_root/DatabaseSpecificBackEnd.pm";
IPCHelper::RunCmd( $cmd , "Unable to copy file" );


################################################################################
# Preparing Genomeview
PREPARING_GENOME_VIEW:
$log->info("Preparing genome viewer...");

my $base_url 	 = $p{url} . $p{dataset_name};
my $genome_fasta = $p{genome_fasta};
my $gff 	 = $p{gff};
my $bam_list 	 = $p{bam_list};

if( $p{genome_fasta} ne '' ){
	# Add sample number to each alias on the bam_list
	print STDERR "Creating Genomeview instance ...\n";
	`awk 'BEGIN{cont=0} {print \$1 " (s"cont")",\$2; cont++}' FS="\t" OFS="\t" $bam_list > $bam_list.new`;	

	`genomeview.pl $base_url $html_root $genome_fasta $gff $bam_list.new`;
}



##################################################################
# Final arrangements
FINAL_ARRANGEMENTS:
$log->info("Final arrangements...");

# Checking if Apache user is already a PostgreSQL
eval "require casa_constants_for_installer";

my $dbh = DBI->connect( $CASA::DSN, $CASA::DB_USER, $CASA::DB_PASSWORD )
  or $log->logexit(
  "Couldn't connect to $CASA::DB using string $CASA::DSN as $CASA::DB_USER\n"
  . DBI->errstr );
  
my $apache_user_exists = VCFDB::user_exists( $dbh, 'www-data' );


if( not $apache_user_exists ){
	$cmd = 'create user "' . $p{apache_user} . '";';
	DBHelper::executeCmdPsql( 	$cmd,
					$p{psql_database_name}, 
					$p{psql_database_user}, 
					$p{psql_bin_dir} );
}


# Transfering the privileges from the user $p{psql_database_user} 
# to the Apache user (on PostgreSQL) so the web-front end can access polydb database
$cmd = 'grant "' . $p{psql_database_user} . '" to "' . $p{apache_user} . '";';
DBHelper::executeCmdPsql( 	$cmd,
				$p{psql_database_name}, 
				$p{psql_database_user}, 
				$p{psql_bin_dir} );
	
# Vacuum database
$log->info( "Vacuum database. This could take several minutes...\n" );
IPCHelper::RunCmd( [ $p{psql_bin_dir} . '/vacuumdb', '--analyze', $p{psql_database_name} ] , 
	'Unable to vacuum database' . $p{psql_database_name} . '!!' );

################################################################################

print "\n";
print "\n";
print "************************************************************************************************************\n";
print "\tWEB FRONT-END CAN BE ACCESSED THROUGH:\n";
print "\thttp://" . $cgibin_url . "/home_menu.cgi\n";

print "\n";
print "\tWe love our customers!\n";
print "\n";

print "\t,d88b.d88b,\n";
print "\t88888888888\n";
print "\t\`Y8888888Y\'\n";
print "\t  \`Y888Y'\n";
print "\t    \`Y\'\n";
print "\n";

print "************************************************************************************************************\n";


exit(0);




	
