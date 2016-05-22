sudo apt-get update
sudo apt-get autoremove
sudo apt-get install -y --force-yes apache2
sudo apt-get install libpq-dev
sudo apt-get install r-base-core
sudo apt-get install libdb4.8-dev
# Install Perl

# Install Postgres


psql -c 'CREATE DATABASE polydb;' -U postgres

# CPAN Modules
sudo apt-get install cpanminus
sudo cpanm Config::Validate
sudo cpanm File::System
sudo cpanm DBD::Pg
sudo cpanm Template
sudo cpanm Algorithm::Combinatorics
sudo cpanm Log::Log4perl
sudo cpanm Term::ProgressBar
svn export http://svn.code.sf.net/p/vcftools/code/ vcftools
sudo cpanm CGI::Session::File
sudo cpanm --notest Paranoid
sudo cpanm Parse::PlainConfig
sudo cpanm IPC::Run
sudo cpanm URI::Escape
sudo cpanm DB_File
sudo cpanm Text::Markdown
sudo cpanm File::Slurp
