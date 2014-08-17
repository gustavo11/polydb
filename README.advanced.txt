PolyDB v1.0 - Oct 16, 2013
==========================

PolyDB is a software package that converts genotype calls stored in VCF files into a PostgreSQL database and a custom made web front-end, allowing the easy exploration of genetic variatons by users who are not familiar with tools to query the original VCF files. The availability of the variants through a web interface also allows remotely located collaborators to query and download data.


1. INSTALLING
=============

The setup of PolyDB in *advanced mode* involves taking note of directory paths and configuration values that are specific to the user's host. Those values should be then tranfered this information to PolyDB's configuration file.

Any information that should remembered and later transfered to PolyDB configuration file will be indicated by the following disclaimer:

**This information should be provided in PolyDB's configuration file as 'variable_name'** 

where 'variable_name' indicates the name of the variable in the PolyDB configuration file where the information should be transfered to.
 

1.1 - Server requirements
-------------------------
Identify the UNIX/Linux server that will host PolyDB.
 
This server should have the following applications installed:

- PostgreSQL server. Follow installation instructions here: http://www.postgresql.org/docs/9.1/static/admin.html

- Apache web server. Follow installation instructions here: http://httpd.apache.org/docs/2.4/install.html

- Perl interpreter. Usually already installed as part of UNIX/Linux default environment. 

- R language interpreter. Follow installation instructions here: http://cran.r-project.org/doc/manuals/r-release/R-admin.html 

- JBrowse (Optional). Follow installation instructions here: http://jbrowse.org/install

PostgreSQL, Apache, R and Perl can be also installed via package managers such as Yum, APT and Synaptic (the later being a graphical interface for APT package manager).
For example, using APT the installation of those applications can be accomplished by issuing the following commands:

$ sudo apt-get install apache2
$ sudo apt-get install postgresql
$ sudo apt-get install libpq-dev
$ sudo apt-get install perl
$ sudo apt-get install r-base-core

1.5 - Download PolyDB
---------------------

Create a directory 


Download either the stable version of PolyDB from
http://www.broadinstitute.org/polydb/download/polydb_latest.tar.gz

or the version containing the latest additions from Github:



1.2 - Configuring PostgreSQL
----------------------------

1.2.1 - Identify directory path to PostgreSQL binaries

Issue the command below to identify the directory where PostgreSQL binaries are located in your system:

$ ps -ef | grep postgres | grep -v 'postgres:' | grep -v 'grep'

Example output: 
$ postgres  1759     1  0 Sep14 ?        00:00:29 /usr/lib/postgresql/9.1/bin/postgres -D /var/lib/postgresql/9.1/main -c config_file=/etc/postgresql/9.1/main/postgresql.conf

In the example above, the PostgreSQL binaries are located in /usr/lib/postgresql/9.1/bin

**The full path to PostgreSQL binaries should be provided in PolyDB's configuration file as 'psql_bin_dir'** 


1.2.2 - Create or identify a database in the local instance of PostgreSQL that will be used by PolyDB to store the variant calls

We recommended a separate database to store PolyDB tables, but any previously created database can be used. The newly created or chosen database has to be provided to PolyDB through its configuration file together with a user name and password associated to an account with write access to that database, including 'create table' permission.

If you prefer to create a new database, please see below an example on how to create a database named 'polydb'  accessible by the user 'john':

- Issue the following command:

$ sudo -u postgres createuser -P john

- A prompt will appear requesting a password. Please provide one. It doesn't have to be the same password used in authentication of a login into the Linux/Unix system.
Answer the next prompted question by indicating that the user is not a super user, but it can create tables and additional roles.

Then issue the following commands
$ sudo -u postgres psql  -c "CREATE DATABASE polydb" 
$ sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE polydb to john";

In the commands above the word jonh should be sustituted by your user name.

**The database name should be provided in PolyDB's configuration file as 'psql_database_name'** 

**The user name should be provided in PolyDB's configuration file as 'psql_database_user'** 

**The user password should be provided in PolyDB's configuration file as 'psql_database_password'** 


1.2.3 - Identifies which port psql is listening to

Issue the command below to identify the number of the port psql daemon is listening to:
$ pg_lsclusters

**This port number should be provided in PolyDB's configuration file as 'psql_port'** 



1.3 - Configuring Apache
------------------------

1.3.1 Identify the user associated to httpd daemon

Identify the user associate to Apache's httpd daemon running on your server. Contact your system administrator if needed.
In most Linux/Unix installations the user running the httpd daemons is either 'apache' or 'www-data'

**This information should be provided in PolyDB's configuration file as 'apache_user'** 


1.3.2 Create a subdirectory in htdocs directory which will host all polydb sites

Identify the location of Apache's DocumentRoot on your server. Contact your system administrator if needed.
In a standard Linux installation of Apache the DocumentRoot is:
/var/www/

Then either create or ask your system administrator to create a directory in the DocumentRoot that will host all PolyDB web sites.
This directory should be writeable by anyone.
Example:
$ sudo mkdir /var/www/polydb
$ sudo chmod a+w /var/www/polydb


**The full path of PolyDB's subdirectory in DocumentRoot should be provided in PolyDB's configuration file as 'html_base'** 


1.3.3 Create a subdirectory in cgi-bin directory which will contain the web front end scripts

Identify the location of Apache's cgi-bin directory on your server. Contact your system administrator if needed.
In a standard Linux installation of Apache the path to cgi-bin directory is:
/usr/lib/cgi-bin

Then either create or ask your system administrator to crate a subdirectory in the cgi-bin directory that will contain the web front end scripts. 
This directory should be writeable by anyone.
Example:
$ sudo mkdir /usr/lib/cgi-bin/polydb
$ sudo chmod a+w /usr/lib/cgi-bin/polydb

**The full path of PolyDB's subdirectory in cgi-bin should be provided in PolyDB's configuration file as 'cgibin_root'** 

1.3.4 URL of the host

Determine the hostname where PolyDB is being installed. Contact your system administrator if needed.
Example:
www.myhost.org

**The hostname should be provided in PolyDB's configuration file as 'host'** 


1.3.4 URL of future PolyDB web pages

Determine the URL pointing to future PolyDB-generated web pages. Inform your system administrator of the location of PolyDB subdirectory in DocumentRoot and he/she will be able to provide you the full URL that points to that location.
Example:
www.myhost.org/polydb

**The URL should be provided in PolyDB's configuration file as 'url'** 


1.4 - Installing required Perl libraries
----------------------------------------
PolyDB requires the following CPAN modules:

- Parse::PlainConfig
- Config::Validate
- File::System
- DBD::Pg
- TemplateToolkit
- Algorithm::Combinatorics
- Log::Log4perl
- Term::ProgressBar


Those can be installed using CPAN modules. But first certify that CPAN modules is already configured by issuing the command below:
$ sudo perl -MCPAN -e shell
If the command above returns the prompt 'cpan[1]>' or similar prompt then the CPAN module is already configured. So quit the cpan shell by typing:
cpan[1]> quit

If the command returns a text saying that 'CPAN requires configuration...' follow the steps for automatic configuration of CPAN and select the 'sudo' option when asked for "how to prepare the Perl library".
Select the default option in every other question. Quit CPAN after the configuration is done by typing:
cpan[1]> quit


Now you are ready to install the required Perl modules. Issue the following commands:

$ sudo perl -MCPAN -e 'install Parse::PlainConfig'
$ sudo perl -MCPAN -e 'install Config::Validate'
$ sudo perl -MCPAN -e 'install File::System'
$ sudo perl -MCPAN -e 'install DBD::Pg'
$ sudo perl -MCPAN -e 'install Template'
$ sudo perl -MCPAN -e 'install Algorithm::Combinatorics'
$ sudo perl -MCPAN -e 'install Log::Log4perl'
$ sudo perl -MCPAN -e 'install Term::ProgressBar'


In addition to those modules, PolyDB requires the Vcf.pm file, part of the VCFTools library.
The complete VCFTools library does not have to be installed, just download VCFTools from SourceForge (https://sourceforge.net/projects/vcftools/), decompress the file in a directory that you own and keep note of the full path to the subdirectory 'perl' in the uncompressed VCFTools directory tree. 
Example:
/home/john/vcftools_0.1.11/perl 


**The path to the Vcf.pm file should be provided in PolyDB's configuration file 'vcf_pm_dir'**



1.5 - Adjusting host-specific configuration file
------------------------------------------------

Now we need to transfer all gathered information to PolyDB's host-specific configuration file.

First create your own host-specific config file by copying from a template file distributed with PolyDB.
Use as the prefix the name of the new file th name of server hosting PolyDB. And VERY IMPORTANT, the filename should have 'host-specific.config' as a suffix.

$ cd $POLYDB_HOME
$ cp template.host-specific.config  myhost.host-specific.config

In the commands above "$POLYDB_HOME' should be substituted by the directory where PolyDB is located; and 'myhost' should be substituted by the hostname hosting PolyDB.

Next add all in the information gathered during the installation process to its corresponding place in the host-specific config file. The variable in the host-specific file that should contain each piece of information is indicated in the lines above quoted with two asterisks '**'.

To confirm that the configuration file was correctly adjusted, please execute the script 'test_host-specific_config.pl'. No parameters are required:

$ cd $POLYDB_DIR
$ ./test_host-specific_config.pl

Please correct any error reported by this script.
If no errors are reported then you have succesfully configured PolyDB.


2. Creating a PolyDB database and web site from the sample data distributed with PolyDB
=======================================================================================

Set the sample_data subdirectory of the PolyDB HOME as the current directory:
$ cd 

- Copy the template configuration file from PolyDB HOME to your working directory. We recommend to use the 'dataset name' as the prefix of the destination file
Example:
$ cp my_polydb_home_directory/configuration_file_template.conf my_dataset_name.conf

- Modify the configuration file according to instructions in its content

- Execute PolyDB installer.
Example:

$ my_polydb_home_directory/polydb_installer.pl --conf my_dataset_name.conf


4. Creating a PolyDB database from your own VCF files
=====================================================

4.1 - Generate Annotated VCF files 
----------------------------------

To generate annotated VCF you will need a GFF3 file describing annotation of the reference genome used in the genotype calls.
Then, from the directory containing the VCF files, use the execute the following command for each VCF file that will be processed by PolyDB:

$ my_polydb_home_directory/vcfannotator/VCF_annotator.pl --gff3 gff3_of_reference --genome genome.fas --vcf vcf_file

In the command above: 
- please specify your PolyDB home directory where it says 'my_polydb_home_directory'.
- indicate the path of the reference file where it says 'gff3_of_reference'
- indicate the path of the VCF file being annotated where it says 'vcf_file'

In case you are planning to upload several VCF files use the instructions below to automate the VCF annotation:
- Create a file listing all the path the VCF files that will be annotated. A easy way to create this file is to execute the following command from the directory containing all VCF files:
$ ls *.vcf > all_vcfs

From the same directory execute the following commands
$ tcsh
$ foreach file (`cat all_vcfs`)
$ my_polydb_home_directory/vcfannotator/VCF_annotator.pl \
$ --gff3 gff3_of_reference --genome genome.fas --vcf $file > $file.annot
$ end


In the commands above: 
- please specify your PolyDB home directory where it says 'my_polydb_home_directory'.
- indicate the path of the reference file where it says 'gff3_of_reference'
- indicate the path of the reference genome in FASTA format where it says 'genome.fas' 

4.2 - Preparing BAM files for genome browsers 
----------------------------------

So they can be shown correctly
BAM files should have the MD field so SNPs can be seen in JBrowse. This field is not required for Genomeview.
The MD field can be added using the following Samtools command:

$ samtools calmd -u original_bam_file bam_file_with_md_field

Instruction on how to install Samtools can be found here.

In addition to that, the BAM files should be indexed, that means that those should be acompanied by their correspondent *.bam.bai file in the same directory. If you have generated a new BAM file with MD field using the instruction above then you need to generate a new index file to. Use the comand below:

$ samtools index bam_file


4.2 - Creating PolyDB instance 
----------------------------------

- Decide for a name representing the batch of VCF files that will be processed by PolyDB.
We will refer to it as 'dataset name'.

- We recommended that you create a working directory to deal with each batch of VCF files that will be uploaded into the database.

- Copy the template configuration file from PolyDB HOME to your working directory. We recommend to use the 'dataset name' as the prefix of the destination file
Example:
$ cp my_polydb_home_directory/configuration_file_template.conf my_dataset_name.conf

- Modify the configuration file according to instructions in its content

- Execute PolyDB installer.
Example:
$ my_polydb_home_directory/polydb_installer.pl --conf my_dataset_name.conf


5. PolyDB limitations
=====================
PolyDB was initially designed to store genotype calls on bacterial genomes. 
Because of that haplotype and polyploid information reported in the VCF is currently disregarded by the parser
and not stored in the database. We do plan to implement those features in the near future. 

In addition to that PolyDB also have the following limitations:
- Each VCF file should represent one single sample. VCF files containing multiple results are not accepted.
- Indels and substitutions larger than 255 bp will be discarded.



