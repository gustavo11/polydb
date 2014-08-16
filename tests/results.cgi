#!/bin/env perl
use strict;
use Bio::Seq;
use Bio::SeqIO;
use IO::Handle;
use template_code;

TemplateCode::execute(
	sub {
		my ($cgi,$upload_dir) =  @_;
		
		#open report file
		my $file = $ARGV[0];
		open (FILE, "$upload_dir/final_report.txt") or die "couldn't open File: $upload_dir/final_report.txt";
		
		#reads file into array
		my @array = <FILE>;
		close FILE; #I moved this from the end to here (it should not change anything)
		
		########################################################################
		#generate alignments
		
		#declare variables
		my $inputPepFileName;
		my $inputNucFileName;
		my $len;
		#my $upload_dir = '.';
		my $file;
		my @id;
		my $i;
		my $dump;
		
		$inputPepFileName = "subj_1.and.reads.consensus.n_filter.aln.pep";
		$inputNucFileName = "subj_1.and.reads.consensus.n_filter.aln_again";
		
		#open folder where session data is stored
		opendir(SESSION, $upload_dir) || die("Cannot open directory $upload_dir");
		$dump .= ">>>open dir $upload_dir\n";
		
		#get info on all subfolders and files on it
		my @thefiles= readdir(SESSION); 
		$dump .= ">>>Files in $upload_dir: @thefiles\n";
		close SESSION;
		
		#iterate through folder looking for clone folders
		foreach $file (@thefiles) {
			if ($file =~ /clone_/) {
				chomp $file;
				$dump .= ">>>folder where working: $file\n";
				#print ">>>folder where working: $file\n";
				
				#if a clone folder is found, get info
				my $working_dir = $upload_dir . '/' . $file;
				my $dump .=  "Working_dir is $working_dir";
				#print "Working_dir is $working_dir";
				
				#pre-process files to remove texshade invalid characters from files
				`sed 's/_/-/g' $working_dir/$inputPepFileName > $working_dir/temp_1`;
				`sed 's/_/-/g' $working_dir/$inputNucFileName > $working_dir/temp_2`;
				
				$dump .= ">>>cleaning $working_dir/$inputPepFileName\n";
				$dump .= ">>>cleaning $working_dir/$inputNucFileName\n";
				
				`mv $working_dir/temp_1 $working_dir/$inputPepFileName`;
				`mv $working_dir/temp_2 $working_dir/$inputNucFileName`;
				
				$dump .= ">>moving temp_1 file to $working_dir/$inputPepFileName\n";
				$dump .= ">>moving temp_2 file to $working_dir/$inputNucFileName\n";

				#for now I open each file to find out what is the sequence length. In the future
				#to improve efficiency this numbers could be passed a parameter
				#Open input sequence file
				my $inputSeqIO = Bio::SeqIO->new(-file => "$working_dir/$inputPepFileName", '-format' => 'Fasta');
				while ( my $eachSeq = $inputSeqIO->next_seq() ) {
					@id[$i] = $eachSeq->id();
					$len = $eachSeq->length();
					$i++
				}
				my $seq2 = substr $id[1],0,12;
				
				#LATEX/TEXshade does not like a lot of things. 
				#Easiest solution is to replace them with '-' 
				$seq2 =~ s/_/-/g;
				$seq2 =~ s/@/-/g;
				$seq2 =~ s/{/-/g;
				$seq2 =~ s/}/-/g;
				$seq2 =~ s/\\/-/g;
				$seq2 =~ s/#/\#/g;
				$seq2 =~ s/%/\%/g;
				
				#create file for LATEX code
				my $reportFileName1 = "report1.tex";
				my $reportFileName2 = "report2.tex";
				
				#LATEX CODE
				open(LATEX,">$working_dir/$reportFileName1") or die "$!";
				$dump .= ">>>creating latex file $working_dir/$reportFileName1\n";
				
				print LATEX '\documentclass[a4paper,12pt]{article}' . "\n" .
					'\usepackage{texshade}' . "\n" .
					'\begin{document}' . "\n".
					'\begin{texshade}' . '{./' . "$inputPepFileName}\n" .
					"\t".	'\shadingmode[allmatchspecial]{identical}' . "\n" .
					"\t". 	'\setends{1}{1..' . "$len}" . "\n" .
					"\t".	'\hideconsensus' ."\n" .
					"\t".	'\namesrm\namessl' ."\n" .
					"\t".	'\hidenumbering\showruler{top}{1}' ."\n" .
					"\t".	'\shownames{left}' ."\n" .
					"\t".	'\nameseq{1}{Ref Seq}' . "\n" .
					"\t".	'\nameseq{2}{' . $seq2 .'}' . "\n" .
					'\end{texshade}' . "\n" .
					'\end{document}';
				close LATEX;
				$dump .= ">>>saving $working_dir/$reportFileName1\n";
				
				open(LATEX,">$working_dir/$reportFileName2") or die "$!";
				print LATEX '\documentclass[a4paper,12pt]{article}' . "\n" .
					'\usepackage{texshade}' . "\n" .
					'\begin{document}' . "\n".
					'\begin{texshade}' . '{./' ."$inputNucFileName}\n" .
					"\t".	'\shadingmode{diverse}' . "\n" .
					"\t".	'\namesrm\namessl' ."\n" .
					"\t".	'\hidenumbering\showruler{top}{1}' ."\n" .
					"\t".	'\shownames{left}' ."\n" .
					"\t".	'\nameseq{1}{Ref Seq}' . "\n" .
					"\t".	'\nameseq{2}{' . $seq2 .'}' . "\n" .
					'\end{texshade}' . "\n" .
					'\end{document}';
				close LATEX;
				$dump .= ">>>saving $working_dir/$reportFileName2\n";
				
				#run latex and generate figure
				`latex -output-directory=$working_dir $working_dir/$reportFileName1` or die "$!";
				`latex -output-directory=$working_dir $working_dir/$reportFileName2` or die "$!";
				$dump .= ">>>saving $working_dir/report1.dvi\n";
				$dump .= ">>>saving $working_dir/report2.dvi\n";
				
				#make pdf in clone folder
				`dvipdf $working_dir/report1.dvi $working_dir/report1.pdf`;
				`dvipdf $working_dir/report2.dvi $working_dir/report2.pdf`;
				$dump .= ">>>saving $working_dir/report1.pdf\n";
				$dump .= ">>>saving $working_dir/report2.pdf\n";
				
			}
		}
		########################################################################
		
		#iniatilize variables
		my @columns;
		my @list;
		
		#parse data (only if there is data on all expected values)
		foreach my $line (@array) {
			chomp($line);
			my ($garbage, $rest) = split(/clone_/,$line);
			@columns = split(/ +/, $rest); #data is currently split based on spaces
			if (scalar @columns >7) {
				for (my $i=0; $i<scalar @columns; $i++) {
					push (@list, $columns[$i]);
				}
			} 
		}
		
		# Defining the core of the home page
		my $vars = {
			core  => 'results',
			list  => sub { return @list }, 
			tab_state => 'Results',  	
			dump => $dump,
		};
		return ( $vars );
	}
	
	);
