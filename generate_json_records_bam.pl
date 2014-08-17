#!/bin/env perl

use strict;
use Utils;

my $prefix   			= $ARGV[0];
my $bam_file 			= $ARGV[1];
my $bam_desc 			= $ARGV[2];
my $json_track_list_file 	= $ARGV[3]; 
my $only_coverage 		= $ARGV[4];

my $json_out;


if ( not $only_coverage ){
$json_out .= <<JSON;
      {
         "storeClass" : "JBrowse/Store/SeqFeature/BAM",
         "urlTemplate" : "$bam_file",
         "label" : "$bam_file",
         "type" : "JBrowse/View/Track/Alignments2",
         "baiUrlTemplate" : "$bam_file.bai",
         "chunkSizeLimit" : 2000000,
         "key" : "$prefix, alignment, $bam_desc"
      },
JSON
}


$json_out .= <<JSON;
      {
         "storeClass" : "JBrowse/Store/SeqFeature/BAM",
         "urlTemplate" : "$bam_file",
         "label" : "$bam_file.coverage",
         "type" : "JBrowse/View/Track/SNPCoverage",
         "baiUrlTemplate" : "$bam_file.bai",
         "key" : "$prefix, SNP & coverage, $bam_desc"
      }      
JSON


my $json_track_content = Utils::leArq( $json_track_list_file );

$json_track_content =~ s/\"tracks\"\s*:\s*\[([\w\W\n]+)\]/\"tracks\" : \[\1\,\n$json_out]/;

`cp $json_track_list_file $json_track_list_file.bak`;

#print $json_track_content;
Utils::salvaArq( $json_track_list_file, $json_track_content );



