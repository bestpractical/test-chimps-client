#!/usr/bin/perl

use warnings;
use strict;

use Test::Smoke::Report;
use Test::Smoke::Report::Client;
use Test::TAP::Model::Visual;
use YAML::Syck;
use File::Basename;
use File::Temp qw/tempdir/;
use File::Path;

my $config = LoadFile("/home/zev/bps/poll-config.yml");

while (1) {
  foreach my $category (keys %{$config}) {
    my $info_out = `svn info $config->{$category}->{svn_uri}`;
    $info_out =~ m/Revision: (\d+)/;
    my $revision = $1;
    $info_out =~ m/Last Changed Author: (\w+)/;
    my $author = $1;

    next unless $revision > $config->{$category}->{revision};

    $config->{$category}->{revision} = $revision;

    my $tmpdir = tempdir("smoke-svn-XXXXXXX", TMPDIR => 1);

    system("svn co $config->{$category}->{svn_uri} $tmpdir > /dev/null");

    chdir(File::Spec->catdir($tmpdir, $config->{$category}->{root_dir}));
    my $libdir = File::Spec->catdir($tmpdir,
                                    $config->{$category}->{root_dir},
                                    'lib');

    unshift @INC, $libdir;

    my $start_time = time;
    my $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t t/*/t/*.t"));
    my $duration = time - $start_time;

    shift @INC;

    chdir(File::Spec->rootdir);
    rmtree($tmpdir, 0, 0);
  
    my $report = Test::Smoke::Report->new(model => $model,
                                          extra_data =>
                                          { category => $category,
                                            subcategory => 'repository snapshot / Linux',
                                            project => scalar fileparse($config->{$category}->{svn_uri}),
                                            revision => $revision,
                                            author => $author,
                                            timestamp => scalar gmtime,
                                            duration => $duration });

    my $client = Test::Smoke::Report::Client->new(reports => [$report],
                                                  server => 'http://galvatron.mit.edu/cgi-bin/report_server.pl');

    my ($status, $msg) = $client->send;

    if (! $status) {
      print "Error: $msg\n";
    }
    DumpFile("/home/zev/bps/poll-config.yml", $config);
  }
  sleep 300;
}

