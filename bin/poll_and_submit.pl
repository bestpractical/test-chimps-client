#!/usr/bin/env perl

use warnings;
use strict;

use Test::Chimps::Client::Poller;
  
my $poller = Test::Chimps::Client::Poller->new(
  server      => 'http://galvatron.mit.edu/cgi-bin/report_server.pl',
  config_file => "$ENV{HOME}/poll-config.yml",
);

$poller->poll;
