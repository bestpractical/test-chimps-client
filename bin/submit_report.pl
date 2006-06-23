#!/usr/bin/perl

use warnings;
use strict;

use lib '/home/zev/bps/Test-Smoke-Report/trunk/lib';

use Getopt::Long;
use Test::Smoke::Report;
use Test::Smoke::Report::Client;
use Test::TAP::Model::Visual;

chdir "jifty/trunk";

my $start_time = time;
my $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t t/*/t/*.t"));
my $duration = time - $start_time;

my $report = Test::Smoke::Report->new(model => $model,
                                      extra_data =>
                                      { category => 'Jifty',
                                        subcategory => 'repository snapshot / Linux',
                                        project => 'jifty',
                                        revision => 5,
                                        timestamp => scalar gmtime,
                                        duration => $duration });

my $client = Test::Smoke::Report::Client->new(reports => [$report],
                                              server => 'http://galvatron.mit.edu/cgi-bin/report_server.pl');

my ($status, $msg) = $client->send;

if (! $status) {
  print "Error: $msg\n";
  exit(1);
}
