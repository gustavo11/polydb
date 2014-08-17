#!/bin/tcsh

#jbrowse.sh $datase_name $jbrowse_dir $genome_fasta $gff

set data_id=$1
set jbrowse_dir=$2
set fasta_genome=$3
set GFF=$4
set bam_list=$5

set code_dir=/seq/aspergillus1/gustavo/devel/automation/jbrowse
set jbrowse_data_dir=$jbrowse_dir/data/$data_id

set prefix=$data_id

rm -r $jbrowse_data_dir
mkdir $jbrowse_data_dir
cd $jbrowse_dir

#####################
# Reference sequence
bin/prepare-refseqs.pl --fasta $fasta_genome --out $jbrowse_data_dir


#####################
# GFF

set temp_GFF=$jbrowse_data_dir/$prefix.gff
cp $GFF $temp_GFF


# Converting utrs to 'UTR' (Jbrowse only understand feature 'UTR')
sed -i 's/three_prime_utr/UTR/' $temp_GFF
sed -i 's/five_prime_utr/UTR/' $temp_GFF

gff_rewrite.pl $temp_GFF $temp_GFF.clean keep_id 1 0

# Adding Name=<gene name> attribute to every feature. 
#awk '{print $9}' FS="\t" $temp_GFF.clean | awk '{print $2";"}' FS=";" | \
#sed 's/\.t..//g' | sed 's/_mRNA//' | sed 's/-T;/;/' | sed 's/Parent/Name/' > temp
#~/devel/tab_file/dumbJoin.pl $temp_GFF.clean temp > temp3
#awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9$10}' OFS="\t" FS="\t" temp3 > $jbrowse_data_dir/$prefix.gff3

# 'tracklabel' is a computer key (do not use spaces or special characters)
# 'key' is a human readable label
# 'type' - indicates the main feature. 'mRNA' should be used here

bin/flatfile-to-json.pl \
--out $jbrowse_data_dir \
-gff $temp_GFF.clean \
--type "mRNA" \
--className "transcript" \
--arrowheadClass "transcript-arrowhead" \
--getSubs --subfeatureClasses '{"CDS": "transcript-CDS"}' \
--tracklabel "models" \
--key "Gene models"



######################
# Add index making genes searchable
#bin/generate-names.pl --verbose --out $jbrowse_data_dir

# And then add autocomplete to the feature record in the $jbrowse_data_dir/trackList.json:
#echo "autocomplete" : "all",


##############################
# BAM

cp $jbrowse_data_dir/trackList.json $jbrowse_data_dir/trackList.json.bak.old

cd $jbrowse_data_dir

foreach line ("`cat $bam_list`")

	echo $line
	set bam_alias=`echo $line | awk '{print $1}'`
	set bam_file=`echo $line | awk '{print $2}'`
	
	set track_prefix="short_reads"
	set bam_desc="$track_prefix $bam_alias"

	rm $jbrowse_data_dir/$bam_alias.bam
	rm $jbrowse_data_dir/$bam_alias.bam.bai
	
	ln -s $bam_file $jbrowse_data_dir/$bam_alias.bam
	ln -s $bam_file.bai $jbrowse_data_dir/$bam_alias.bam.bai

	# Execute the command below and then add the output
	# to $jbrowse_data_dir/trackList.json
	$code_dir/generate_json_records_bam.pl $track_prefix $bam_alias.bam "$bam_desc" $jbrowse_data_dir/trackList.json

end



