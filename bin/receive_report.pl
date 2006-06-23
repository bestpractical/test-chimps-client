#!/usr/bin/perl

use lib '/home/zev/bps/Test-Smoke-Report/trunk/lib';

use Test::Smoke::Report::Server;

my $server = Test::Smoke::Report::Server->new(base_dir => '/var/www/bps-smokes',
                                              validate_extra =>
                                                   { base_dir =>
       { type => SCALAR,
         optional => 0 },
       bucket_file =>
       { type => SCALAR,
         default => 'bucket.dat',
         optional => 1 },
       burst_rate =>
       { type => SCALAR,
         optional => 1,
         default => 5,
         callbacks =>
         { "greater than or equal to 0" =>
           sub { $_[0] >= 0 }} },
       max_rate =>
       { type => SCALAR,
         default => (1 / 30),
         optional => 1,
         callbacks =>
         {"greater than or equal to 0" =>
          sub { $_[0] >= 0 }} },
       max_size =>
       { type => SCALAR,
         default => 2**20 * 3.0,
         optional => 1,
         callbacks =>
         { "greater than or equal to 0" =>
           sub { $_[0] >= 0 }} },
       max_smokes_same_category =>
       { type => SCALAR,
         default => 5,
         optional => 1,
         callbacks =>
         { "greater than or equal to 0" =>
           sub { $_[0] >= 0 }} },
       report_dir =>
       { type => SCALAR,
         default => 'reports',
         optional => 1 },
       validate_extra =>
       { type => HASHREF,
         optional => 1 }});


$server->handle_request;
