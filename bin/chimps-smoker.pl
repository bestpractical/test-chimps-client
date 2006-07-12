#!/usr/bin/env perl

use warnings;
use strict;

use Test::Chimps::Smoker;
  
my $poller = Test::Chimps::Smoker->new(
  server      => 'http://galvatron.mit.edu/cgi-bin/report_server.pl',
  config_file => "$ENV{HOME}/poll-config.yml",
);

$poller->smoke;
