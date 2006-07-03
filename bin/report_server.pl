#!/usr/bin/env perl

use lib '/home/zev/bps/Test-Chimps/branches/categories-rework/lib';

use Test::Chimps::Server;

my $server = Test::Chimps::Server->new(base_dir => '/var/www/bps-smokes',
                                       list_template => 'list2.tmpl',
                                       variables_validation_spec =>
                                       { project => 1,
                                         revision => 1,
                                         author => 1,
                                         timestamp => 1,
                                         duration => 1,
                                         osname => 1,
                                         osver => 1,
                                         archname => 1
                                       });

$server->handle_request;
