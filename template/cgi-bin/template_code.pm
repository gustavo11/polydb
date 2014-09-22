#!/bin/env perl
package TemplateCode;
use casa_constants;

use strict;
use Template;
use CGI;
use File::Basename;
use CGI::Carp qw ( fatalsToBrowser );  
use CGI::Session::File;

sub errorFunc{
 my ($errorStr,$cgi) = @_;
 CGI::Carp::warningsToBrowser(1);
 print $errorStr . "\n";
}

sub execute{
my ($sub) = @_;

# Base Template
my $baseTemplate = "casa_base";

# Base dir of cgi
my $cgiBaseDir   = $CASA::CGI_BASE_DIR; 

my $cgi = new CGI;
my $sid = $cgi->param("SID") || undef;
my $session = new CGI::Session::File($sid,{
				      LockDirectory=>"/tmp/sessions",
				      Directory    => "/tmp/sessions"
				     });

$sid = $session->id();

print "Content-type: text/html\n\n"; 

################################################
# Store in a string all CGI parameters
# This will be dumped to the browser if in debug mode
my $params     = $cgi->Vars;
my $userInputFromHtmlForm = "";

foreach my $currKey (keys %$params ){
   $userInputFromHtmlForm = $userInputFromHtmlForm . "$currKey: " . $params->{$currKey} . "<BR>";
}

$userInputFromHtmlForm = $userInputFromHtmlForm . "<BR>";
################################################

#################################################
# Preparing template processing
my $tt = Template->new({
    INCLUDE_PATH => $CASA::TEMPLATE_DIR,
    INTERPOLATE  => 1,
}) || die "$Template::ERROR\n";


my $upload_dir = "/tmp/sessions/".$sid;
qx{mkdir -p $upload_dir};

##################################################
# Executing core rendering function
my ($template_vars) = $sub->($cgi, $upload_dir);


##################################################

###################################################
# Store in a string all parameters
# returned by sub 
my $scriptGeneratedValues = "";
foreach my $key (keys %$template_vars ){
   $scriptGeneratedValues = $scriptGeneratedValues . "$key: " . $template_vars->{$key} . "<BR>";
}
$scriptGeneratedValues = $scriptGeneratedValues . "<BR>";

# Add this dump to template vars
$template_vars->{scriptGeneratedValues} = $scriptGeneratedValues;

# Add session id to the template vars
$template_vars->{SID} = $sid;

# Add base dir for cgi
$template_vars->{cgi_base_dir} = $cgiBaseDir;

# Add current user 
$template_vars->{current_user} = $ENV{REMOTE_USER};

# Add DB_SITE_INFO variable
# if 1 links will be shon on the left panel pointing to site map and DB schema
# if 0 no link
$template_vars->{DB_SITE_INFO} = $CASA::DB_SITE_INFO;

# Add CSS base dir
$template_vars->{CSS_BASE_DIR} = $CASA::CSS_BASE_DIR;

# Add web server and port
$template_vars->{WEB_SERVER_AND_PORT} = $CASA::WEB_SERVER_AND_PORT;

# Add species
$template_vars->{SPECIES} = $CASA::SPECIES;
$template_vars->{DB_TABLE} = $CASA::DB_TABLE;

# Add CGI vars dump to template vars
$template_vars->{userInputsFromHtmlForm} = $userInputFromHtmlForm;
#####################################################


#print "SID: $sid   TTtemplate: $baseTemplate Core: " . $template_vars->{core} . "\n";

$tt->process($baseTemplate, $template_vars)
    ||  errorFunc $tt->error(), $cgi;

}

return 1;
