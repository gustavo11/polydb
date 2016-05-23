package IPCHelper;
use strict;
use Carp;
use IPC::Run;
use IPC::Cmd;
use Log::Log4perl;
use Term::ProgressBar;


sub SetEnvAndRunCmdNoOutBuffer{
	my ( $argRef,  $errMsg, $hashRef ) = @_;	
	my ($in, $out, $err);		
	my $full_cmd = join " ", @{$argRef};
	
	my $env_setup_cmds = _generate_setenv_str_( $hashRef );
	

	my $log = Log::Log4perl->get_logger();	
	$log->debug( "CMD: $full_cmd" );
        if( IPC::Run::run( $argRef, \$in,
            	    	      init => sub {
            	    	      	      foreach my $currKey ( keys %{$hashRef} ){
            	    	      	      	      my $currValue = $hashRef->{$currKey};
            	    	      	      	      $ENV{$currKey}=$currValue;
            	    	      	      	      $log->debug( "Seting environment variable $currKey to $currValue" );
            	    	      	      }
            	    	      } ) ){
        	$log->debug( "DONE: $full_cmd" );        	
        }else{
        	$log->fatal( "$errMsg\tCMD: $env_setup_cmds $full_cmd\n" );
        	exit(1);
        }
        
}

sub SetEnvAndRunCmd{
	my ( $argRef,  $errMsg, $hashRef ) = @_;	
	my ($in, $out, $err);		
	my $full_cmd = join " ", @{$argRef};
	
	
	my $env_setup_cmds = _generate_setenv_str_( $hashRef );
			

	my $log = Log::Log4perl->get_logger();	
	$log->debug( "CMD: $full_cmd" );
        if( IPC::Run::run( $argRef, \$in, \$out, \$err,
            	    	      init => sub {
            	    	      	      foreach my $currKey ( keys %{$hashRef} ){
            	    	      	      	      my $currValue = $hashRef->{$currKey};
            	    	      	      	      $ENV{$currKey}=$currValue;
            	    	      	      	      $log->debug( "Seting environment variable $currKey to $currValue" );
            	    	      	      }
            	    	      } ) ){
        	$log->debug( "DONE: $full_cmd" );        	
        }else{
        	$log->fatal( "$errMsg\tCMD: $env_setup_cmds $full_cmd\n" );
        	map( $log->fatal($_), split( "\n", $out ) ) if $out ne "";
        	map( $log->fatal($_), split( "\n", $err ) ) if $err ne "";
        	exit(1);
        }
        
}


sub RunSQLCmdList{
	my ( $argRef,  $errMsg, $task_name, $progress_eta ) = @_;

	# Only using progress bar if the number of insert and/or update lines
	# is higher than 100k
	my $progress;
	my $progress_counter = 0;
	my $previous_update;
	if( $progress_eta >= 1 ){
		$progress = Term::ProgressBar->new( { name => $task_name, count => $progress_eta, remove => 1 });
	}
	
	my $full_cmd = join " ", @{$argRef};
	
	my $log = Log::Log4perl->get_logger();	
	$log->debug( "CMD: $full_cmd" );
	
	my $command_out;
	if( open $command_out, "-|", "$full_cmd 2>&1" ){
		
		while (<$command_out>) {
			my $out = $_;
			
			if( $out =~ /^NOTICE:/  ){				
				$log->debug($out);
			}elsif( $out =~ /^ERROR:/ ){
				$log->logexit($out);				
			}elsif( $out =~ /^INSERT:/ || $out =~ /^UPDATE:/ ){
				$progress_counter++;
				if ( $progress_counter % 1000000 == 0 ) {
					my $m = $progress_counter / 1000000;
					$log->debug( "$m M calls processed ...\n" ) ;
				}
				$progress->update( $progress_counter ) 
				   if( defined $progress );				
			}else{
				$log->debug($out);				
			}
		}
		if( defined $progress ){
			$progress->update( $progress_eta );
			#print "\n";
		}
        }else{        	
		$log->fatal( "$errMsg\tCMD: $full_cmd\n" );
		while (<$command_out>) {
			$log->fatal($_);
		}
        	exit(1);
        }

	$log->debug( "DONE: $full_cmd" );        
}



sub RunCmd{
	my ( $argRef, $errMsg, $verbose ) = @_;

	my $log = Log::Log4perl->get_logger();	
	my $full_cmd;
	if(ref($argRef) eq 'ARRAY'){		
		$full_cmd = join " ", @{$argRef};
	}else{
		$full_cmd = $argRef;
	}	
	
	$log->debug( "CMD: $full_cmd" );	
	
	my( $success, $os_err_msg, $full_buf, $stdout_buf, $stderr_buf ) =
            IPC::Cmd::run( command => $argRef, verbose => $verbose );
        
        if( not $success ){
        	$log->fatal( "$errMsg\tCMD: $full_cmd\n" );
        	map( $log->fatal($_), split( "\n", $os_err_msg ) ) if $os_err_msg ne "";
        	exit(1);        	
        }else{
        	$log->debug( "DONE: $full_cmd" );
        }
        
}


sub RunCmdNoFatal{
	my ( $argRef, $errMsg, $verbose ) = @_;

	my $log = Log::Log4perl->get_logger();	
	my $full_cmd;
	if(ref($argRef) eq 'ARRAY'){		
		$full_cmd = join " ", @{$argRef};
	}else{
		$full_cmd = $argRef;
	}	
	
	$log->debug( "CMD: $full_cmd" );	
	
	my( $success, $os_err_msg, $full_buf, $stdout_buf, $stderr_buf ) =
            IPC::Cmd::run( command => $argRef, verbose => $verbose );
        
        if( not $success ){
        	$log->debug( "$errMsg\tCMD: $full_cmd\n" );
        	map( $log->debug($_), split( "\n", $os_err_msg ) ) if $os_err_msg ne "";
        }else{
        	$log->debug( "DONE: $full_cmd" );
        }
        
}

	# Creating a string with all environment variables listed in
	# $hashRef
	# This string will be printed in case of error, enabling
	# the user to repeat the command in the prompt with the correct
	# environment variables

sub _generate_setenv_str_ {
	my ( $hashRef ) = @_;
	my $env_setup_cmds = "";
	
	foreach my $currKey ( keys %{$hashRef} ){
            	    	      	      	      my $currValue = $hashRef->{$currKey};
            	    	      	      	      $ENV{$currKey}=$currValue;
            	    	      	      	      $env_setup_cmds .= "setenv $currKey $currValue;"

        }
        
        return $env_setup_cmds;
}





return 1;