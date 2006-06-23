#!/usr/bin/perl

use lib '/home/zev/bps/Test-Smoke-Report/trunk/lib';

use Test::Smoke::Report::Server;

my $server = Test::Smoke::Report::Server->new(base_dir => '/var/www/bps-smokes');

$server->handle_request;
