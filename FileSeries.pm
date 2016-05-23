package FileSeries;

use IO::Handle;

sub new {
	my ( $dir, $prefix, $suffix, $max_num_lines, $header, $footer ) = @_;
	my $self = { dir    => $dir,
		     prefix => $prefix,
		     suffix => $suffix,
		     max_num_lines => $max_num_lines,
		     header => $header,
		     footer => $footer,
	};
			  
	bless $self, FileSeries;
	
	$self->{max_num_line_flush} = 100;	
	
	return $self;
}

sub open {
	my $self = shift;

	$self->{line_count} = 0;
	$self->{batch} = 0;
	
	my $filename = $self->get_filename();
	
	open $self->{fh}, ">$filename" or
		die "Unable to open $filename!!!\n";
	print { $self->{fh} } $self->{header} if defined $self->{header};
	
}

sub print{	
	my $self = shift;
	
	my ( $content ) = @_;
	print { $self->{fh} } $content;
	
	$self->line_added();
	
}

sub line_added{
	my $self = shift;
	$self->{line_count} = $self->{line_count} + 1;

	
	if( $self->{line_count} >= $self->{max_num_lines} ){

		print { $self->{fh} } $self->{footer} if defined $self->{footer};
		close($self->{fh});
		
		
		$self->{line_count} = 0;
		$self->{batch} = $self->{batch} + 1;
		
		
		my $filename = $self->get_filename();
		open $self->{fh}, ">$filename" or
		  die "Unable to open $filename!!!\n";
		print { $self->{fh} } $self->{header} if defined $self->{header};
	
	}elsif( $self->{line_count} % $self->{max_num_line_flush} == 0 ){
		$self->{fh}->flush();
	}
		
}

sub close{
	my $self = shift;
	print { $self->{fh} } $self->{footer} if defined $self->{footer};
	close($self->{fh});
}

sub get_filename{
	my ( $self ) = @_;

	
	my $filename =  $self->{dir} . '/' . 
			$self->{prefix} . '.' .
			$self->{batch} . '.' .
			$self->{suffix};
		
	return $filename;
}

return 1;

	
	
	
