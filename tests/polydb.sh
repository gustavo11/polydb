#!/bin/tcsh

####################################################
# This script needs to be executed in the server  
# hosting the web server and postgres

# >>>>>> A T T E N T I O N <<<<< #
# Dataset name cannot contain dots (SQL restriction) neither upper case 
# (it will be converted to lower case by Postgres)

set polydb_template=~/devel/polydb/template
set psql_dir=/seq/gscidA/www-public/htdocs/polydb/psql/bin
set db_string=localhost:polydb:gustavo:livotica
set base_url=timneh.broadinstitute.org/polydb
set base_htdocs=/seq/gscidA/www-public/htdocs/polydb



# Species specific variables

# Dataset name cannot contain dots (SQL restriction)
set dataset_name=$0
set vcf_list=$1
set vcf_list_annot=$2
set html_root=$3
# BASE URL without the http://
set url=$4

# cgibin_root has to be an environment variable. It will be used by vcf2query and vcf2sql to find the correct
# casa_constant.pm directory
unset cgibin_root
setenv cgibin_root $5

set bam_list=$6

# FOR GENOMEVIEW
# A list of files in the following format
#<Alias>\t<full path to original BAM file. Indexes (*.bai files) should be in the same directory>
set bam_list=$7
set genome_fasta=$8
set gff=$9

##################
# For Mycoplasma tuberculosis
set dataset_name=mtuberculosis
set org_alias=m.tuberculosis
set database=polydb
set vcf_list=vcf_list
set vcf_list_annot=vcf_list.annot
set html_root=/seq/gscidA/www-public/htdocs/polydb/$org_alias
set cgibin_root=/seq/gscidA/www-public/htdocs/polydb/$org_alias/cgi-bin
set url=timneh.broadinstitute.org/polydb/
set bam_list=
set genome_fasta=
set gff=

##################
# For candida
set dataset_name=candida
set database=polydb
set vcf_list=vcf_list
set vcf_list_annot=vcf_list.annot
set html_root=/seq/gscidA/www-public/htdocs/polydb/c.albicans
set cgibin_root=/seq/gscidA/www-public/htdocs/polydb/c.albicans/cgi-bin
set url=timneh.broadinstitute.org/polydb/c.albicans
set bam_list=bam_list
set genome_fasta=/seq/references/Candida_albicans_SC5314/v1/Candida_albicans_SC5314.fasta
set gff=/seq/gscidA/Candida/snps/vcf/genenames/C.albicans_SC5314_genes.gnames.gff3

##################
# For Staphylococcus aureus
set dataset_name=saureus
set database=polydb
set vcf_list=vcf_list
set vcf_list_annot=vcf_list.annot
set html_root=/seq/gscidA/www-public/htdocs/polydb/s.aureus
set cgibin_root=/seq/gscidA/www-public/htdocs/polydb/s.aureus/cgi-bin
set url=timneh.broadinstitute.org/polydb/s.aureus

# Genomeview
set bam_list=bam_list
set genome_fasta=/seq/references/Candida_albicans_SC5314/v1/Candida_albicans_SC5314.fasta
set gff=/seq/gscidA/Candida/snps/vcf/genenames/C.albicans_SC5314_genes.gnames.gff3


# b.dorei_CL02T00C15

# Dataset name cannot contain dots (SQL restriction) neither upper case (it will be converted to lower case by Postgres)
set species="Bacteriodes dorei cl02t00c15"
set dataset_name=bdoreicl02t00c15
set database=polydb
set vcf_list=vcf_list
set vcf_list_annot=vcf_list.annot
set html_root=/seq/gscidA/www-public/htdocs/polydb/bdoreicl02t00c15
set locus_id_example=orf19.6115


# cgibin_root has to be an environment variable. It will be used by vcf2query and vcf2sql to find the correct
# casa_constant.pm directory
unset cgibin_root
setenv cgibin_root /seq/gscidA/www-public/htdocs/polydb/$dataset_name/cgi-bin

set url=timneh.broadinstitute.org/polydb/bdoreicl02t00c15

#----------------------------------------------------------------------------


##################################################################
# Preparing host
mkdir $html_root
mkdir $html_root/results
mkdir $cgibin_root
cp -R $polydb_template/cgi-bin/* $cgibin_root
cp -R $polydb_template/htdocs/* $html_root
chmod 777 $html_root/results


generate_contants_file.pl "$species" $db_string  $dataset_name \
$base_url $base_htdocs $locus_id_example  > $cgibin_root/casa_constants.pm



##################################################################
# Populating database

# change line:
# use lib casa_contants.pm
# before executing 
vcf2sql.pl $vcf_list $dataset_name

# Remove lines inserting table vcf_fields

cat "$dataset_name"_create_tables.sql | $psql_dir/psql polydb -U gustavo 


################################################################################
# Trying to detect double calls for the same position.
# Only the first one will be uploaded into the DB. No need for additional measures.

# Example:
# 7000000184540662        24681   .       G       .       2833.68 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97
# 7000000184540662        24681   .       GT      .       3830.50 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97

# OR

# 7000000184540662        499612  .       C       .       2297.85 PASS    AC=0;AF=0.00;AN=2;DP=80;MQ=49.65;MQ0=0  GT:DP   0/0:80
# 7000000184540662        499612  .       C       .       2452.27 PASS    AC=0;AF=0.00;AN=2;DP=82;MQ=50.08;MQ0=0  GT:DP   0/0:82

awk '{print $2}' FS="\t" $vcf_list > $vcf_list.only_path
foreach file ( `cat  $vcf_list.only_path` )
set double_calls=`awk ' $1 == last_chrom && $2 == last_position && $5 == "." && last_alt_genotype == "." {print last_line; print $0}{last_chrom = $1; last_position = $2; last_line = $0; last_alt_genotype = $5}' \
$file FS="\t" | wc -l`
echo $file " number of double calls:" $double_calls
end


################################################################################
# Trying to detect double and DIFFERENT calls for the same position.
# The application don't know how to deal with those. 


# Example:
# 7000000184540662        24681   .       C       .       2833.68 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97
# 7000000184540662        24681   .       G       .       3830.50 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97

#OR

# 7000000184540662        24681   .       CT       .       2833.68 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97
# 7000000184540662        24681   .       GT       .       3830.50 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97

#OR

# 7000000184540662        24681   .       C       G       2833.68 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97
# 7000000184540662        24681   .       C       .       3830.50 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97

#OR

# 7000000184540662        24681   .       C       CG       2833.68 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97
# 7000000184540662        24681   .       C       CT       3830.50 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97

#OR

# 7000000184540662        24681   .       CG       C       2833.68 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97
# 7000000184540662        24681   .       CC       C       3830.50 PASS    AC=0;AF=0.00;AN=2;DP=97;MQ=34.74;MQ0=0  GT:DP   0/0:97


set sample = 0
foreach file ( `cat  $vcf_list.only_path` )
echo "Sample $sample ..."
set double_calls=`awk ' $1 == last_chrom && $2 == last_position && length($5) == length(last_alt_genotype) && length($4) == length(last_ref_genotype) && (last_ref_genotype != $4 || last_alt_genotype != $5 ) {print last_line; print $0}{last_chrom = $1; last_position = $2; last_line = $0; last_alt_genotype = $5; last_ref_genotype = $4}' \
$file FS="\t" | tee s$sample.double_different | wc -l`
echo "\tNumber of double different calls: $double_calls"
echo "\tList of errors saved on: s$sample.double_different"
@ sample++
end



################################################################################
# Compare database with files VCF

# Before anything compare original VCF to annotated VCFs
# It doesn't matter that the DB is not populated yet.
# Several times there was discrepancies between those sets of files


check_db.pl $dataset_name $vcf_list $vcf_list_annot > check_db.results 

##########################################################################
# Populating the database
cat "$dataset_name"_inserts.sql | $psql_dir/psql polydb -U gustavo
$psql_dir/vacuumdb --analyze polydb
cat "$dataset_name"_ref_based_indexes.sql | $psql_dir/psql polydb -U gustavo
cat "$dataset_name"_updates.sql | $psql_dir/psql polydb -U gustavo
$psql_dir/vacuumdb --analyze polydb

#####################################
# Preparing for additional fields gene annotation

brian_annotation_to_sql.pl $vcf_list_annot $dataset_name "$dataset_name".annotated.vcf.sql \
 "$dataset_name".full_annot.sql  >& error.annotated.vcf.txt

cat "$dataset_name".annotated.vcf.sql | $psql_dir/psql polydb -U gustavo >& error.updating.annotated.vcf.txt

# The next step is optional
cat "$dataset_name".full_annot.sql | $psql_dir/psql polydb -U gustavo >& error.updating.full_annot.txt

$psql_dir/vacuumdb --analyze polydb

##############################################
# Create sorted table  !!!!!!!!!!!! Find a way to move all indexes and primary key!!!!!!!!!!!!!

set sorted_dataset="$dataset_name"_sorted

echo "create table $sorted_dataset  as select * from "$dataset_name" order by chrom, position, var_type;" \
| psql polydb -U gustavo

# I have tried, without success, to change the type of the original primary key to serial (id_key)
# So I create another column. This is a good solution, with both columns I can know the order
# of sorted records (id_key_sorted), and the orders which the records were uploaded (id_key)

echo "alter table $sorted_dataset add id_key_sorted SERIAL PRIMARY KEY;" | $psql_dir/psql polydb -U gustavo

###########################################
# Create the rest of the indexes here

# Regenerate the ref based indexes and constraints
sed 's/ON '$dataset_name'/ON '$sorted_dataset'/g' "$dataset_name"_ref_based_indexes.sql \
 | sed 's/index '$dataset_name'/index '$sorted_dataset'/' | sed 's/TABLE '$dataset_name'/TABLE '$sorted_dataset'/' \
 | sed 's/unique_coord___'$dataset_name'/unique_coord___'$sorted_dataset'/' > "$sorted_dataset"_ref_based_indexes.sql

cat "$sorted_dataset"_ref_based_indexes.sql | $psql_dir/psql polydb -U gustavo

# Create the sample based indexes
sed 's/ON '$dataset_name'/ON '$sorted_dataset'/g' "$dataset_name"_sample_based_indexes.sql \
 | sed 's/index '$dataset_name'/index '$sorted_dataset'/'  > "$sorted_dataset"_sample_based_indexes.sql

cat "$sorted_dataset"_sample_based_indexes.sql | $psql_dir/psql polydb -U gustavo

$psql_dir/vacuumdb --analyze polydb

############################################################
# Post-processing DB

vcf2sql_post_process.pl "$sorted_dataset" post_process.sql

# Save table before applying post processing
$psql_dir/pg_dump -o polydb -t $sorted_dataset -U gustavo > \
$sorted_dataset.before_postprocessing.bak

cat post_process.sql | $psql_dir/psql polydb -U gustavo >& error.post_process.txt

# In case of something happened... Reverting to the backup
$psql_dir/psql polydb -U gustavo -c "drop table $sorted_dataset"
cat $sorted_dataset.before_postprocessing.bak | $psql_dir/psql polydb -U gustavo >& error.restoring


$psql_dir/vacuumdb --analyze polydb

############################################################
# Final check of the DB


############# A T T E N T I O N ###########################
# Change the "use lib" line before executing

check_db.pl "$sorted_dataset" $vcf_list $vcf_list_annot > check_db.results 
grep "ERROR" check_db.results | wc

##################################################################
# Creating HTML interface and sorted table

use R-2.12


# 1st boolean parameter indicates if genomeview infrastructure will be assembled (1) or not (0)
# 2nd boolean parameter if boxplot should be added to the query form (1) or not (0)
# 3rd boolean parameter indicates if one additional column containing full annotation added by
# Brians script should be added to the dump file
vcf2query.pl $vcf_list "$sorted_dataset"  0 1 0
cp "$sorted_dataset"_query_database $html_root/DatabaseSpecific_query_database
cp "$sorted_dataset"_query_results $html_root/DatabaseSpecific_query_results
cp "$sorted_dataset"_back_end.pm $cgibin_root/DatabaseSpecificBackEnd.pm



################################################################################
# Preparing Genomeview

use Samtools

# Add sample number to each alias on the bam_list
awk 'BEGIN{cont=0} {print $1 " (s"cont")",$2; cont++}' FS="\t" OFS="\t" $bam_list > $bam_list.new

genomeview.pl $url $html_root $genome_fasta $gff $bam_list.new



