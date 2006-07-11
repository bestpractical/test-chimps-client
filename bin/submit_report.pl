#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use Test::Chimps::Client;
use Test::TAP::Model::Visual;

my $model;
{
  local $SIG{ALRM} = sub { die "10 minute timeout exceeded" };
  alarm 600;
  print "running tests for $project\n";
  eval {
    $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t t/*/t/*.t"));
  };
  alarm 0;                      # cancel alarm
}
        
if ($@) {
  print "Tests aborted: $@\n";
}

my $duration = $model->structure->{end_time} - $model->structure->{start_time};

my $client = Test::Chimps::Client->new(
  model  => $model,
  server => 'http://galvatron.mit.edu/cgi-bin/report_server.pl',
  {
    project   => $project,
    revision  => $revision,
    committer => $committer,
    duration  => $duration,
    osname    => $Config{osname},
    osvers    => $Config{osvers},
    archname  => $Config{archname}
  }
);

my ($status, $msg) = $client->send;

if (! $status) {
  print "Error: $msg\n";
  exit(1);
}
