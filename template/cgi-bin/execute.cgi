#!/usr/bin/env perl
use strict;

use template_code;

TemplateCode::execute(
  sub {
  	my ($cgi,$upload_dir) =  @_;
  	
  	
  	#################################################################
  	# If the user just asked to start the execution
  	# If no execution have been started during this session
  	# Then execute command and show the progress bar
  	
  	if( $cgi->param("execute") eq "true" && !(-e "$upload_dir/lock_logfile.txt" ) ){
  		# Assinchronous execution
  		system("bash $upload_dir/cmd.sh > $upload_dir/lock_logfile.txt &");
  	}	
  	
  	
  	
  	
  	###########################################################
  	# If the user have started the execution of the script
  	# but its not done yet
  	# Then show the progress bar
  	#if(-e "$upload_dir/lock_logfile.txt"){
  	
  	
  	###########################################################	
  	# If the user didn't start the execution or
  	# he is returning after issuing the execution 
  	# Then ask for a ticket
  #}else{
  	
  #}
  
  # Defining the core of the home page
  my $vars = {
  	core  => 'progress_bar',
  	tab_state => 'Results',
  };
  
  
  return ( $vars );
  }
  );
