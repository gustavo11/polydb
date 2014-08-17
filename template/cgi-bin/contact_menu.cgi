#!/usr/bin/env perl
use strict;

use template_code;

TemplateCode::execute(
  sub {
   my ($cgi,$upload_dir) =  @_;

   # Defining the core of the home page
   my $vars = {
     core     => 'contact_menu',
     tab_state => 'Contact'
   };

    return ( $vars );
  }
);
