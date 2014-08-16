use R-3.0
use Perl-5.8
use Samtools

setenv TMPDIR /local/scratch

# Scripts
setenv DEVEL_DIR /seq/aspergillus1/gustavo/devel
setenv USR_LOCAL /seq/aspergillus1/gustavo/usr/local
setenv USR_LIB  /seq/aspergillus1/gustavo/usr/lib
setenv POLYDB_DIR /seq/aspergillus1/gustavo/devel/polydb/stable

setenv PATH  ${PATH}:${DEVEL_DIR}/automation/genomeview
setenv PATH  ${PATH}:${DEVEL_DIR}/automation/jbrowse
setenv PATH  ${USR_LOCAL}/bin:${PATH}
setenv PATH  ${PATH}:${DEVEL_DIR}/bin
setenv PATH  ${POLYDB_DIR}:${PATH}

setenv PERL5LIB ${DEVEL_DIR}/lib
setenv PERL5LIB ${PERL5LIB}:${DEVEL_DIR}/gff/gfflib:${USR_LIB}/lib/perl5:${DEVEL_DIR}/mauve
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/perl5
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/5.8.9
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/site_perl/5.8.9
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/site_perl/5.8.9/x86_64-linux-thread-multi
setenv PERL5LIB ${PERL5LIB}:${USR_LIB}/lib/site_perl/5.8.9/x86_64-linux-thread-multi/auto
setenv PERL5LIB ${POLYDB_DIR}:${PERL5LIB}

#IGV
setenv PATH ${PATH}:${USR_LOCAL}/IGV_2.0.9
setenv PATH ${PATH}:${USR_LOCAL}/IGVTools

