How the sample was generated
============================

cd /seq/aspergillus2/berl_mutants/batch_2

grep '^#' 717_GCCAAT_L001_R1_001.filtered.annot.vcf > s3.header
grep '^#' RuthControl_CCGTCC_L001_R1_001.filtered.annot.vcf > s4.header

head -n 10  717_GCCAAT_L001_R1_001.filtered.pol_sites.vcf.double_calls > s3.doubles
head -n 10  s3.double_different >> s3.doubles

head -n 10  RuthControl_CCGTCC_L001_R1_001.filtered.pol_sites.vcf.double_calls > s4.doubles
head -n 10  s4.double_different >> s4.doubles

cat s3.header s3.doubles > s3.vcf

cat s4.header s4.doubles > s4.vcf


How to test
===========

cd ~/devel/polydb/tests/check_fix_vcf.pl

~/devel/polydb/stable/check_fix_vcf.pl vcf_list vcf_list.test log
