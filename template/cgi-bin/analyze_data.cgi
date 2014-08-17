#!/usr/bin/env perl
use strict;

use template_code;

TemplateCode::execute(
  sub {
   my ($cgi,$upload_dir) =  @_;

   my $query = $cgi->param("query");
   my $query_clean = $query;
   $query_clean =~ s/ limit [\w\W]*?;/;/;

   # Defining the core of the home page
   my $vars = {
     core     => 'analyze_page',
     tab_state => 'Query',
     query     => $query_clean,
   };

    return ( $vars );
  }
);
