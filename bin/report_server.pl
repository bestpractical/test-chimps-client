#!/usr/bin/perl

use lib '/home/zev/bps/Test-Smoke-Report/trunk/lib';

use Test::Smoke::Report::Server;

my $server = Test::Smoke::Report::Server->new(base_dir => '/var/www/bps-smokes',
                                              extra_validation_spec =>
                                              { category => 1,
                                                subcategory => 1,
                                                project => 1,
                                                revision => 1,
                                                timestamp => 1,
                                                duration => 1 });

$server->handle_request;
