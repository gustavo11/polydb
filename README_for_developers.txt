Apache configuration on timneh:
/seq/gscidA/www-public/myPublic.conf

Starting Apache on timneh:
==========================
cd /seq/gscidA/www-public
source /seq/aspergillus1/gustavo/devel/polydb/config_files/broad_timneh.env.sh
sh start_apache.cmd


To create clean VM to test installation
=======================================

- Create a VM using your Ubuntu 12.04 CD
- Install apache, postgre, R using the following commands
sudo apt-get install apache2
sudo apt-get install postgresql
sudo apt-get install r-base-core
sudo apt-get install openssh-server


VM on pretinho
==============
172.16.11.129


Generating Manual in HTML format
================================

cd /seq/aspergillus1/gustavo/devel/polydb/stable
/seq/aspergillus1/gustavo/devel/HTML/README2html.pl README.txt out.html

Copy out.html to the core of manual.html content.




Testing PolyDB
==============

cd /seq/aspergillus2/polydb/vcf/eurocoli/sample_for_polydb_web_site/small
cd /seq/aspergillus2/berl_mutants/batch_2


source /seq/aspergillus1/gustavo/devel/polydb/config_files/broad_timneh.env.devel.sh

/seq/aspergillus1/gustavo/devel/polydb/stable/polydb_installer.pl \
--config sample_data.conf


nice ~/devel/polydb/stable/polydb_installer.pl --config berl.polydb.test.conf


Exporting PolyDB for Broad usage
==========================================

# Remove old code
cd /seq/aspergillus2/polydb/code
rm -r stable
rm -r config_files

# Exporting code
set host=http://pretinho.dyndns-blog.com/svn
svn export $host/devel/polydb/stable
svn export $host/devel/polydb/config_files

# Adjusting the configuration files so PolyDB can work properly at Broad
cd stable 

cp /seq/aspergillus1/gustavo/devel/lib/IPCHelper.pm .
cp /seq/aspergillus1/gustavo/devel/lib/DBHelper.pm .
cp /seq/aspergillus1/gustavo/devel/lib/FileSeries.pm . 
cp /seq/aspergillus1/gustavo/devel/automation/genomeview/genomeview.pl . 
cp /seq/aspergillus1/gustavo/devel/automation/jbrowse/generate_json_records_bam.pl .
cp /seq/aspergillus1/gustavo/devel/automation/jbrowse/jbrowse.sh .


cp ../config_files/broad_timneh.conf configuration_file_template.conf
cp ../config_files/broad_timneh.env.sh polydb_env.sh
cp ../config_files/broad_timneh.sample_data.conf sample_data/sample_data.conf
rm -r ../config_files


Exporting tar.gz of Polydb for web site download
=================================================

tcsh
set date=`date | awk '{print $2"_"$3"_"$6}'`

# EITHER
# From outside home

set host=http://pretinho.dyndns-blog.com/svn
set web_site=~/devel/polydb/website

# OR
# From home

set host=http://localhost/svn
set web_site=/data/devel/polydb/website



mkdir polydb_$date
cd polydb_$date
svn export $host/devel/polydb/stable
mv polydb/stable/* .
rm -r polydb/stable

cp /seq/aspergillus1/gustavo/devel/lib/IPCHelper.pm .
cp /seq/aspergillus1/gustavo/devel/lib/DBHelper.pm .
cp /seq/aspergillus1/gustavo/devel/lib/FileSeries.pm .
cp /seq/aspergillus1/gustavo/devel/automation/genomeview/genomeview.pl . 
cp /seq/aspergillus1/gustavo/devel/automation/jbrowse/generate_json_records_bam.pl .
cp /seq/aspergillus1/gustavo/devel/automation/jbrowse/jbrowse.sh .



cd ..
tar cvzf polydb_$date.tar.gz polydb_$date
rm -r polydb_stable

mv polydb_$date.tar.gz  $web_site/download
svn rm $web_site/download/polydb_latest.tar.gz
cd $web_site/download
ln -s polydb_$date.tar.gz polydb_latest.tar.gz  
svn add polydb_$date.tar.gz 
svn add polydb_latest.tar.gz  


Setting authentication on few PolyDB pages
==========================================


# Setting authentication using the master Apache conf
cd /seq/gscidA/www-public/htdocs/polydb/

htpasswd -c /seq/gscidA/www-public/htdocs/polydb/passwd polydb
password: acidonucleico


cat > section.txt
        <Directory /seq/gscidA/www-public/htdocs/polydb/###DIR### >
                Options Indexes FollowSymLinks MultiViews
                Options +ExecCGI
                AddHandler cgi-script cgi pl                
                AllowOverride None
                Order allow,deny
                allow from all
                AuthType Basic
                AuthName "Restricted area"
                AuthUserFile /seq/gscidA/www-public/htdocs/polydb/passwd
                Require valid-user
        </Directory>

rm add_apache_conf
foreach dir (b.fragilis b.uniformis s.aureus m.tuberculosis bdoreicl02t00c15 bfragiliscl05t00c42 bfragiliscl03t00c08 bfragiliscl07t00c01 buniformiscl03t00c23 efaecium_ny1_timeseries_v2 saureus_test efaecium_ny1_timeseries efaecium_ny1_timeseries_full efaecium_ny2_timeseries_v2 efaecium_ny2_timeseries ecoli_kte204128 wp5_chrplas)
echo $dir
sed "s/###DIR###/$dir/" section.txt >> add_apache_conf
end

cat /seq/gscidA/www-public/myPublic.original.conf add_apache_conf >  /seq/gscidA/www-public/myPublic.conf


# Setting authentication using a .htaccess in each protected directory

Create a .htaccess on each directory that you want to protect. And thats it

cat > .htaccess
Options Indexes FollowSymLinks MultiViews
Options +ExecCGI
AddHandler cgi-script cgi pl     
AuthType Basic
AuthName "Password Required"
AuthUserFile /www/passwords/password.file
Require Group admins

OR

cat > .htaccess
                Options Indexes FollowSymLinks MultiViews
                Options +ExecCGI
                AddHandler cgi-script cgi pl                
                AllowOverride None
                Order allow,deny
                allow from all
                AuthType Basic
                AuthName "Restricted area"
                AuthUserFile $FILE
                Require valid-user



Improve installation
====================

- at the current state the home page only works if 
casa_constant.pm is added with line
use lib '../../lib';
- All CPAN modules can be installed as a "bundle"
- Use two configuration files, host specific and dataset specific. The host speficic will be adjusted during the installation process and will be kept in home directory.
By default the application will use the host specific configuration in the homedir. But anyother can be specified.
- VM containing PolyDB


Site map
========

PolydDB - Site map
==================

Main structure
--------------
casa_base:
        includes header  (static)
        includes core    (dynamic)
        includes footer  (static, contains left panel)


CORE
----

Tab Home
home_menu.cgi -> home_menu

Tab Query database
query_database.cgi -> query_database 
        Buttone "Submit query!"
        execute_query.cgi -> query_results

                Button "Analyze data"
                analyze_data.cgi    -> analyze_page
                        Button "send"
                        R_image_page.cgi        -> R_image_page                                                                                          

                Button "Download"
                dump_query_data.cgi -> link_to_dump


Tab Support
support_menu.cgi    -> support_menu

Tab Contact us
contact_menu.cgi    -> contact_menu

Tab References
references_menu.cgi -> references_menu


URLS
====
home
http://$host$/polydb/$data_set_name$/cgi-bin/home_menu.cgi

cgi-bin (when internal to htdocs)
http://$host$/polydb/$data_set_name$/cgi-bin

cgi-bin (when cgi-bin in /usr/lib)
http://$host$/polydb/cgi-bin/$data_set_name$



Allowing execution of Scripts from htdocs:
##########################################


<Directory "/seq/gscidA/www-public/htdocs">
    Options +ExecCGI
    AllowOverride Limit
    DirectoryIndex index.html index.cgi
    AddHandler cgi-script .cgi

    Order Allow,Deny
    Allow from All

    <FilesMatch "\.ini">
        Deny from all
    </FilesMatch>
</Directory>


Create two scripts:
- installer that sets the common directories, databases and users: install.pl
- add dataset that just add a dataseet to an installation: add_dataset.pl




# Research

http://www.cpan.org/modules/INSTALL.html


Installing local lib
http://search.cpan.org/dist/local-lib/lib/local/lib.pm#The_bootstrapping_technique

curl -L http://cpanmin.us | perl - App::cpanminus


jbrowse uses FatPacker to pack all dependencies of cpanminus in a single script.
Then distribute the cpanm with it.
Jbrowse also use local::libs



# Installing local::lib

wget http://search.cpan.org/CPAN/authors/id/E/ET/ETHER/local-lib-1.008011.tar.gz
tar xvzf local-lib-1.008011.tar.gz
cd local-lib-1.008011/


perl Makefile.PL --bootstrap
make test && make install

set | grep SHELL

if bash
- echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >> ~/.bashrc

if csh
- perl -I$HOME/perl5/lib/perl5 -Mlocal::lib >> ~/.cshrc


- % cpan App::cpanminus
- Choose [local::lib]
- Choose the default answer for the next questions

cpanm File::System
cpanm Parse::PlainConfig
cpanm Config::Validate
cpanm Template
cpanm Algorithm::Combinatorics
cpanm Log::Log4perl
cpanm Term::ProgressBar
cpanm CGI::Session::File
cpanm DBD::Pg


- install VCFtools
http://sourceforge.net/projects/vcftools
- the lib of vcftools has to be added to PERL5LIB:
/usr/local/vcftools_0.1.7/perl/

# Automation
curl -L http://sourceforge.net/projects/vcftools/files/vcftools_0.1.9.tar.gz/download | tar -xz
cp vcftools_0.1.9/perl/Vcf.pm ~/perl5/lib/perl5/


