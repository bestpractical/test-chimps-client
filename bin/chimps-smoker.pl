#!/usr/bin/env perl

use warnings;
use strict;

use Test::Chimps::Smoker;
use File::Spec;
use Getopt::Long;

my $server;
my $config_file = File::Spec->catfile($ENV{HOME}, 'smoker-config.yml');
my $iterations = 'inf';
my $projects = 'all';

my $result = GetOptions("server|s=s", \$server,
                        "config_file|c=s", \$config_file,
                        "iterations|i=i", \$iterations,
                        "projects|p=s", \$projects);
if (! $result) {
  print "Error during argument processing\n";
  exit 1;
}

if (! defined $server) {
  print "You must specify a server to upload results to\n";
  exit 1;
}

if ($projects ne 'all') {
  $projects = [split /,/, $projects];
}

my $poller = Test::Chimps::Smoker->new(
  server      => $server,
  config_file => $config_file
);

$poller->smoke(iterations => $iterations,
               projects => $projects);
