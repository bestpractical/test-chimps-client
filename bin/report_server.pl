#!/usr/bin/env perl

use Test::Chimps::Server;

my $server = Test::Chimps::Server->new(base_dir => '/var/www/bps-smokes',
                                       variables_validation_spec =>
                                       { category => 1,
                                         subcategory => 1,
                                         project => 1,
                                         revision => 1,
                                         author => 1,
                                         timestamp => 1,
                                         duration => 1 });

$server->handle_request;
