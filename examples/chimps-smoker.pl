#!/usr/bin/env perl

use warnings;
use strict;

use Test::Chimps::Smoker;
  
my $poller = Test::Chimps::Smoker->new(
  server      => 'http://example.com/cgi-bin/chimps-server.pl',
  config_file => "$ENV{HOME}/poll-config.yml",
);

$poller->smoke;
