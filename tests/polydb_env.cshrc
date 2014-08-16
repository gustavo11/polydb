# Checking if this file was already sourced
if( ! ( $?ALREADY_SOURCED_POLYDB ) ) then

# Flag indicating if it was already sourced
setenv ALREADY_SOURCED_POLYDB 1

use EMBOSS
use R-3.0
use Perl-5.8
use Python-2.6
use Subversion-1.6

use Bowtie
use Tophat

setenv TMPDIR /local/scratch

# Scripts
setenv DEVEL_DIR /seq/aspergillus1/gustavo/devel
setenv USR_LOCAL /seq/aspergillus1/gustavo/usr/local
setenv USR_LIB	/seq/aspergillus1/gustavo/usr/lib

setenv PATH  ${PATH}:/seq/aspergillus1/gustavo/polydb
setenv PERL5LIB ${PERL5LIB}:${DEVEL_DIR}/polydb

setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/perl5
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/5.8.9
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/site_perl/5.8.9
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/site_perl/5.8.9/x86_64-linux-thread-multi
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/site_perl/5.8.9/x86_64-linux-thread-multi/auto

else
echo "Skipping polydb_env.cshrc. Already sourced."
echo "Shell and environment variables already loaded ..."
endif
