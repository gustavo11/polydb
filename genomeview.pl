#!/usr/bin/env perl
use Cwd 'abs_path';

#use strict;

my $usage =
"$0 <base URL without http> <full path to htdocs> <genome FASTA> <GFF> <BAM file list*>\n"
  . "\t\t*Format: <Alias>\t<full path to original BAM file. Indexes (*.bai files) should be in the same directory>\n\n";

die $usage if scalar(@ARGV) != 5;

my $url     		= $ARGV[0];
my $htdocs		= $ARGV[1];
my $genome_fasta 	= $ARGV[2];
my $gff          	= $ARGV[3];

my $dir = getcwd;

# Format <Alias>\t<BAM file>
my $bam_list = $ARGV[4];

# Creating genomeview directory
if( not -d  "$htdocs/genomeview" ){
	`mkdir $htdocs/genomeview`;
}

$htdocs .= "/genomeview";
$url    .= "/genomeview";


my @bam;
open BAM, "$bam_list";
while (<BAM>) {
	my $line = $_;
	chomp($line);
	my ( $alias, $temp_path ) = split "\t", $line;
	
	# Absolute path
	my $path = abs_path($temp_path);

	my @dirs = split "/", $path;
	my ($bam_name) = pop @dirs;

	print "Alias: $alias\tPath: $path\tName: $bam_name\n";
	
	push @bam, { alias => $alias, path => $path, name => $bam_name };
}
close(BAM);

##################################
# Generating gvconfig.txt
open OUT, ">$htdocs/gvconfig.txt";

my $out_str = <<OUT_STR;
integration:monitorJavaScript=true
geneticCodeSelection=true

track:weight:gene=1
track:weight:mRNA=2
track:weight:CDS=3
track:weight:exon=4

OUT_STR

my $weight = 20;

if( not -d  "$htdocs/BAMS" ){
	`mkdir $htdocs/BAMS`;
}

foreach my $currBam (@bam) {
	my $bam_path = $currBam->{path};
	my $alias    = $currBam->{alias};
	my $bam_name = $currBam->{name};

	my $file = "$htdocs/BAMS/$bam_name";
	`rm $file`  if ( -e $file );
	`ln -s $bam_path $file\n`;
	
	$file = "$htdocs/BAMS/$bam_name.bai";
	`rm $file`  if ( -e $file );	
	`ln -s $bam_path.bai $file\n`;

	$out_str .= <<OUT_STR;
track:weight:http://$url/BAMS/$bam_name=$weight
track:visible:http://$url/BAMS/$bam_name=false
track:alias:http://$url/BAMS/$bam_name=$alias


OUT_STR

	$weight++;
}

print OUT $out_str;

close(OUT);

##################################
# Generating index.html
open OUT, ">$htdocs/index.html";

`cp $gff $htdocs/annot.gff3`;
`cp $genome_fasta $htdocs/temp.fas`;

# Cleaning FASTA
`fasta2line $htdocs/temp.fas | awk '{print \$1,\$2}' OFS="\t" | line2fasta > $htdocs/genome.fa`;
`cd $htdocs; samtools faidx genome.fa`;

$out_str = <<OUT_STR;
<html>
  <body>
    <h1>Opening Genomeview...</h1><BR>
    Please, only close this window after you are done with this session! 
    <script type="text/javascript" src="http://www.java.com/js/deployJava.js"></script>
    <script type="text/javascript" src="http://genomeview.org/start/genomeview.js"></script>
    <script type="text/javascript">
     	var gv_url	= 'http://$url/genome.fa';
     	var gv_config	= 'http://$url/gvconfig.txt';    
       	var gv_location	= null;
	    var gv_extra    = 'http://$url/annot.gff3 ';
OUT_STR

foreach my $currBam (@bam) {
	my $bam_path = $currBam->{path};
	my $alias    = $currBam->{alias};
	my $bam_name = $currBam->{name};

	$out_str .= <<OUT_STR;
		gv_extra += 'http://$url/BAMS/$bam_name ';
OUT_STR
}

$out_str .= <<OUT_STR;
        startGV(gv_url,gv_location,gv_config,gv_extra,1200,800);
    </script>
  </body>
</html>
OUT_STR

print OUT $out_str;

close(OUT);

##################################
# Generating session.php
open OUT, ">$htdocs/session.php";

$out_str = <<OUT_STR;
##GenomeView session -- DO NOT DELETE THIS LINE
U http://$url/genome.fa
U http://$url/annot.gff3
OUT_STR

foreach my $currBam (@bam) {
	my $bam_path = $currBam->{path};
	my $alias    = $currBam->{alias};
	my $bam_name = $currBam->{name};

	$out_str .= <<OUT_STR;
U http://$url/BAMS/$bam_name
OUT_STR
}

print OUT $out_str;

close(OUT);
