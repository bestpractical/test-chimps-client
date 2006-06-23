#!/usr/bin/perl

use warnings;
use strict;

use lib '/home/zev/bps/Test-Smoke-Report/trunk/lib';

use Getopt::Long;
use Test::Smoke::Report;
use Test::Smoke::Report::Client;
use Test::TAP::Model::Visual;

chdir "jifty/trunk";

my $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t"));# t/*/t/*.t"));

my $report = Test::Smoke::Report->new(model => $model);

my $client = Test::Smoke::Report::Client->new(reports => [$report],
                                              server => 'http://galvatron.mit.edu/cgi-bin/receive_report.pl');

my ($status, $msg) = $client->send;

if (! $status) {
  print "Error: $msg\n";
  exit(1);
}
