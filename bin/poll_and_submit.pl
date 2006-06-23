#!/usr/bin/env perl

use warnings;
use strict;

use Test::Chimps::Client::Poller;
  
my $poller = Test::Chimps::Client::Poller->new(
  server      => 'http://smoke.bestpractical.com/cgi-bin/report_server.pl',
  config_file => '/home/zev/bps/poll-config.yml',
  simulate    => 1
);

$poller->poll;
