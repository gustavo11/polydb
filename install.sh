sudo apt-get --assume-yes update
sudo apt-get --assume-yes autoremove
sudo apt-get --assume-yes install -y --force-yes apache2
sudo apt-get --assume-yes install libpq-dev
sudo apt-get --assume-yes install r-base-core
sudo apt-get --assume-yes install libdb6.0-dev
# Install Perl

# Install Postgres
sudo -u postgres createuser -s cerca
sudo -u postgres psql -c "CREATE DATABASE polydb"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE polydb to cerca"
				
						
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

sudo ./polydb_installer.pl --config .vm.configuration_file.conf --skip_warning