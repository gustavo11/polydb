package Utils;
use Carp;
use strict;

my $pag_erro = "pagina_erro.html";


# Read matrix from file
# Returns:
# - an array with the horizontal header labels
# - an array with the vertical header labels
# - an array with the arrays of arrays with matrix content, first index line, second index column

sub readTabDelimMatrix {
	
	my ($filename) = @_;
	
	open IN, "$filename" or croak "Unable to open file $filename";
	my $matrix = 0;
	my @vheader;
	my @hheader;
	my @matrix;
	my $matrix_line = 0;
		
	while (<IN>) {
		my $line = $_;
		chomp $line;
		
		next if $line =~ /^$/;
		
		
		my @cols = split '\t', $line;
		my $num_fields = scalar( @cols );

		# If $line corresponds to the horizontal header ...
		if( $matrix_line == 0 ){
			# Remove the first col
			shift @cols;
			@hheader = @cols;	
			$matrix_line++;
			next;
		}
		
		
		# Save left header
		my $vheader_name = shift @cols;			
		push @vheader, $vheader_name;
		
		for ( my $ind = 0 ; $ind <= scalar(@cols) ; $ind++ ) {
			push( @{ $matrix[$matrix_line-1] }, $cols[$ind] );
		}
		
		$matrix_line++;
	}
	close(IN);
	
	
	my $debug = 0;
	if( $debug ){
		my $line_num = 0;
		
		foreach my $curr_line ( @vheader ){
			my $col_num = 0;
			foreach my $curr_col ( @hheader ){
				print "[$line_num][$col_num] $curr_line $curr_col " . $matrix[$line_num][$col_num] . "\n";
				$col_num++;
				getc();
			}
			$line_num++;
		}
	}
			
	
	return ( \@hheader, \@vheader, \@matrix );
}


# Reads file and return an array (line) of hashes (cols), keys of hashes (column name) is given as parameters
sub tab_file_to_hash {
	my ( $file_name, $has_header, $arrRef_col_names ) = @_;
	
	my @lines;
	
	my $refArr = tab_file_to_array( $file_name );
	
	if ($has_header) {
		$arrRef_col_names = $refArr->[0];
		confess "Not implemented yet";
	}
	else {
		foreach my $curr_line ( @lines ){
			split '\t', $curr_line; 
		}
		
	}
	
}

# Reads file and return an array of arrays: [lines][cols]
sub tab_file_to_array {
	my ($file_name) = @_;
	open IN, $file_name or croak "Unable to open file $file_name\n";
	
	my @lines;
	while (<IN>) {
		my $curr_line = $_;
		chomp $curr_line;
		#print $curr_line ."\n";
		push @lines, split "\t", $curr_line;
	}
	return \@lines;
}


# Single column file to array
sub file_to_array {
	my ($file_name) = @_;
	open IN, $file_name or croak "Unable to open file $file_name\n";
	my @lines = <IN>;
	close IN;
	return @lines;
}

# Single column file to hash
sub file_to_hash {
	my ($file_name) = @_;
	open IN, $file_name or croak "Unable to open file $file_name\n";
	
	my %lines;
	while (<IN>) {
		my $curr_line = $_;
		chomp $curr_line;
		#print $curr_line ."\n";
		$lines{$curr_line} = 1;
	}
	
	close IN;
	return %lines;
}


sub leArq {
	my ($nomeArq) = @_;
	open ARQ, $nomeArq or warn "Unable to open file $nomeArq\n";
	my @todoArq = <ARQ>;
	close ARQ;
	my $todoArqStr = join "", @todoArq;
	return $todoArqStr;
}

sub salvaArq {
	my ( $nomeArq, $conteudo ) = @_;
	open ARQ, ">$nomeArq" or warn "Unable to save file $nomeArq\n";
	print ARQ $conteudo;
	close ARQ;
}

sub paginaErro {
	my ( $cgi, $mensagem_erro );
	open ARQ_ERRO, $pag_erro;
	my @todoArq = <ARQ_ERRO>;
	close ARQ_ERRO;
	
	my $todoArqStr = join "", @todoArq;
	$todoArqStr =~ s/<!--mensagem-->/$mensagem_erro/s;
	
	print $cgi->header();
	print $todoArqStr;
}

sub uploadArquivo {
	my ( $cgi, $nome_param, $nome_arq ) = @_;
	
	# Fazendo upload do arquivo
	my $filename = $cgi->param($nome_param);
	$filename =~ s/.*[\/\\](.*)/$1/;
	my $upload_filehandle = $cgi->upload($nome_param);
	open UPLOADFILE, ">$nome_arq";
	while (<$upload_filehandle>) {
		print UPLOADFILE;
	}
	
	close UPLOADFILE;
}

sub leArquivoUpload {
	my ( $cgi, $nome_param ) = @_;
	
	# Fazendo upload do arquivo
	my $filename = $cgi->param($nome_param);
	$filename =~ s/.*[\/\\](.*)/$1/;
	my $upload_filehandle = $cgi->upload($nome_param);
	
	my @todoArq = <ARQ>;
	my $todoArqStr = join "", @todoArq;
	return $todoArqStr;
}

sub trim {
	my ($str)    = @_;
	my ($result) = ( $str =~ /\s*([\W\w]*)/ );
	my $tmp      = reverse $result;
	($result) = ( $tmp =~ /\s*([\W\w]*)/ );
	$tmp = reverse $result;
	
	return $tmp;
}

sub question {
	my ($question, $refValidAnswers, $default_answer_index) = @_;
	
	my $list_spacer = ', ';
	my $a_valid_answer = 0;
	my $answer;
	
	while( $a_valid_answer == 0 ){
	
		my $valid_answers_str = '';
		for(my $ind = 0; $ind < scalar( @{$refValidAnswers} ); $ind++ ){
			my $valid_answer = $refValidAnswers->[ $ind ];
			if ( $ind == $default_answer_index ){
				$valid_answers_str .= "DEFAULT:\'$valid_answer\'"
			}else{
				$valid_answers_str .= "\'$valid_answer\'";
			}
			$valid_answers_str .= $list_spacer;
		}
		$valid_answers_str =~ s/$list_spacer$//;

		print "[QUESTION] - $question $valid_answers_str  ";
		   
		$answer = <>;
		chomp $answer;
		
		if( $answer eq '' && $default_answer_index != -1 ){
			$answer = $refValidAnswers->[$default_answer_index];
		}
		
		$a_valid_answer = 1 if grep( /\Q$answer\E/, @{$refValidAnswers});
	}
	
	return "$answer";
}
	

return 1;

