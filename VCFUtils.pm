package VCFUtils;

sub alpha_order_alleles {
	my ($genotype) = @_;
	
	my @nt = split ",", $genotype;
	
	my $sorted_genotype = join( ",", sort(@nt) );
	
	return $sorted_genotype;
}




# Recebe um array bidimensional contendo nucleotideos em cada celula
# e possivel cabecalho horizontal e vertical.
# Retorno o mesmo array em formato HTML e nucleotideo coloridos de acordo com base

sub color_nt_array {
	my ( $refArr, $num_col_headers, $num_row_headers, $refCols, $refHeader ) = @_;
	
	$out_html .= <<HTML;	
	<style type="text/css">
	nt_A { background-color: #66FF99; } 
	nt_T { background-color: #FF0000; }
	nt_C { color: white; background-color: #3366FF; }
	nt_G { background-color: #FFCC00; }
	comma { color: white; background-color: #000000; }
	</style>
HTML
	
	
	
	#$out_html .= "<table>\n";
	$out_html .= "<table id=NTTbl cellpadding=\"0\" cellspacing=\"0\" style=\"width:100%;\">";
	
	$out_html .= "<tr>\n";
	foreach my $currHdrItem ( @{$refHeader} ){
		$out_html .= "<td><font size=1><center>$currHdrItem</center></font></td>";		
	}
	$out_html .= "\n</tr>\n";		
	
	
	my $row_num = 1;
	my $ref;
	foreach my $row ( @{$refArr} ) {
		$out_html .= "<tr>\n";
		my $col = 1;
		foreach my $cell ( @{$row} ) {
			
			$ref = $cell if $col == 3;
			
			if( not in_array($col, $refCols) ){
				$col++;
				next;
			}  
			
			$out_html .= "<td>";
			
			# It is a header			
			if( $col <= $num_col_headers || $row_num <= $num_row_headers ){
				$out_html .= "<center><font size=1>$cell</font></center>";
			}else{
				#$cell = $ref if $cell eq "";
				my $uc_cell = uc($cell);	
				#$uc_cell =~ s/(\S)/add_color_nt($1)/eg;
				
				$uc_cell =~ s/([ACGT])/<nt_$1>$1<\/nt_$1>/g;
				$uc_cell =~ s/,/<comma>-<\/comma>/g;
				
				$out_html .= $uc_cell;		
			}								
			$out_html .= "</td>";								
			$col++;
		}
		$out_html .= "\n</tr>\n";		
		$row_num++;
	}
	$out_html .= "</table>\n";
	return $out_html . "\n";
}

sub in_array{
	my ( $item, $arrRef ) = @_;
	
	foreach my $currItem ( @{$arrRef} ){
		return 1 if $item eq $currItem; 
	}
	
	return 0;
}

sub add_color_nt{
	my ($nt) = @_;
	
	if ( $nt eq "A" ) {
		$cor = "#3366FF";
	}
	
	elsif ( $nt eq "C" ) {
		$cor = "#66FF99";
	}
	
	elsif ( $nt eq "G" ) {
		$cor = "#FFCC00";
	}
	
	elsif ( $nt eq "T" ) {
		$cor = "#FF0000";
	}
	my $out = "<font color=\"$cor\">$nt</font>";
	
	
	return $out;
}


sub valid_annotated_vcf{
	my ( $vcf_file_list ) = @_;

	my $line_num = 1;
	open VCF_LIST, $vcf_file_list or return 0;
	while (<VCF_LIST>) {
		my $line = $_;
		chomp($line);
		
		if ( $line =~ /^#/ || $line =~ /^[\s\t]*$/ ){
			$line_num++;
			next;
		}
		
		my @cols = split "\t", $line;		
		return 0 if ( ( scalar(@cols) != 2 && scalar(@cols) != 3 ) || $cols[0] eq "" || $cols[1] eq "" );
		
		my ( $name, $filename, $num_genotype_calls ) = @cols;
		
		return 0 if( not -e "$filename.annot" );
		
		$line_num++;
	}
	close(VCF_LIST);
	
	return 1;
}

sub valid_vcf_list{
	my ( $vcf_file_list ) = @_;

	my $line_num = 1;
	open VCF_LIST, $vcf_file_list or return 0;
	while (<VCF_LIST>) {
		my $line = $_;
		chomp($line);
		
		if ( $line =~ /^#/ || $line =~ /^[\s\t]*$/ ){
			$line_num++;
			next;
		}
		
		my @cols = split "\t", $line;		
		return 0 if ( ( scalar(@cols) != 2 && scalar(@cols) != 3 ) || $cols[0] eq "" || $cols[1] eq "" );
		
		my ( $name, $filename, $num_genotype_calls ) = @cols;
		
		return 0 if( not -e $filename );
		
		$line_num++;
	}
	close(VCF_LIST);
	
	return 1;
}



sub read_vcf_list{
	my ( $vcf_file_list, $log ) = @_;

	my 	@sample_names;
	my	@vcf_list;
	my	@num_calls;

	my $line_num = 1;
	open VCF_LIST, $vcf_file_list or $log->logexit( "Unable to open the file \'$vcf_file_list\'" );
	while (<VCF_LIST>) {
		my $line = $_;
		chomp($line);
		
		if ( $line =~ /^#/ || $line =~ /^[\s\t]*$/ ){
			$line_num++;
			next;
		}
		
		my @cols = split "\t", $line;
		
		if ( ( scalar(@cols) != 2 && scalar(@cols) != 3 ) || $cols[0] eq "" || $cols[1] eq "" ) {
			$log->fatal( "\nError on line number $line_num\n" );
			$log->fatal( "Line:\'$line\'\n" );
			$log->fatal( "VCF file list should have the following format in every line:\n" );
			$log->logexit( "<sample name>\\t<full path to correspondent VCF>\\t[Optionally: number of genotype calls\n\n\n" );
		}
		
		my ( $name, $filename, $num_genotype_calls ) = @cols;
		
		push @sample_names, $name;
		push @vcf_list, $filename;
		push @num_calls, $num_genotype_calls;
		
		$sample_id{$filename} = scalar(@vcf_list) - 1;
		
		$line_num++;
	}
	close(VCF_LIST);
	
	return ( \@sample_names, \@vcf_list, \@num_calls, \%sample_id );
	
}


sub write_vcf_list{
	my ( $vcf_file_list, $refSampleNames, $refVCFList, $refNumCalls, $log ) = @_;
	
	if( -e $vcf_file_list ){		
		`cp $vcf_file_list $vcf_file_list.bak`;
	}
	
	open VCF_LIST, ">$vcf_file_list" or $log->logexit( "Unable to open the file \'$vcf_file_list\'" );
				
	for( my $ind = 0; $ind < scalar(@{$refSampleNames}); $ind++ ){

		my $sample_name 	= $refSampleNames->[ $ind ];
		my $vcf_file 		= $refVCFList->[ $ind ];
		my $num_genotype_calls = $refNumCalls->[ $ind ];
	
		print VCF_LIST "$sample_name\t$vcf_file\t$num_genotype_calls\n";
	}
	close(VCF_LIST);
	`rm $vcf_file_list.bak`;
		
}

sub read_pol_sites{
	my ( $dataset_name, $log ) = @_;

	my %sites;
	
	my $line_num = 1;
	my $filename = "$dataset_name.polymorphic_sites";

	open POL, $filename or die "Unable to open $filename!\n";
	while(<POL>){		
		my $line = $_;
		next if $line =~ /^#/;
		chomp($line);
		my ($chrom,$pos) = split '\t', $line;
		
		$sites{$chrom}{$pos} = 1;		
	}
	close(POL);

	return \%sites;
}



return 1;



