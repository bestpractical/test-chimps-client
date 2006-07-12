#!/usr/bin/env perl

use warnings;
use strict;

use lib '/home/zev/bps/Test-Chimps-dbi/lib';

use YAML::Syck;
use Jifty::DBI::Handle;
use Jifty::DBI::SchemaGenerator;
use IO::Dir;
use File::Spec;
use Test::TAP::Model::Visual;
use Test::Chimps::Report;
use DateTime;
use Date::Parse;

package Test::Chimps::Report::Schema;

column($_, type(is('text'))) for (
  qw/
  project
  revision
  committer
  timestamp
  duration
  osname
  osvers
  archname
  /
);

package main;

my $handle = Jifty::DBI::Handle->new();
$handle->connect(driver => 'SQLite', database => '/home/zev/bps/database');
my $sg = Jifty::DBI::SchemaGenerator->new($handle);
$sg->add_model(Test::Chimps::Report->new(handle => $handle));
  
$handle->simple_query($_) for $sg->create_table_sql_statements;

my $rec = Test::Chimps::Report->new(handle => $handle);

my $dir = shift;
my $d = IO::Dir->new($dir)
  or die "Could not open report directory: $dir: $!";
while (defined(my $entry = $d->read)) {
  next unless $entry =~ m/\.yml$/;
  my $report = LoadFile(File::Spec->catfile($dir, $entry));
  my $params = {};

  $params->{model_structure} = $report->{model_structure};
  
  foreach my $var (keys %{$report->{report_variables}}) {
    $params->{$var} = $report->{report_variables}->{$var};
  }
  $params->{report_html} = $report->{report_text};

  my $model = Test::TAP::Model::Visual->new_with_struct($report->{model_structure});
  foreach my $var (
    qw/
    total_ok
    total_passed
    total_nok
    total_failed
    total_percentage
    total_ratio
    total_seen
    total_skipped
    total_todo
    total_unexpectedly_succeeded
    /)
  {
    $params->{$var} = $model->$var;
  }

  foreach my $var (qw/category subcategory/) {
    delete $params->{$var};
  }
  
  if (exists $params->{author}) {
    $params->{committer} = $params->{author};
    delete $params->{author};
  }

  if ($params->{project} eq 'BTDT') {
    $params->{project} = 'Hiveminder';
  }

  if ($params->{project} eq 'trunk') {
    if ($params->{revision} > 1750) {
      $params->{project} = 'SVK-Trunk';
    } else {
      $params->{project} = 'Jifty';
    }
  }

  if ($params->{project} eq '1.0-releng') {
    $params->{project} = 'SVK-Releng';
  }

  $params->{project} =~ s/^\l(.)/\u$1/;

  $params->{timestamp} =
    DateTime->from_epoch(epoch => str2time($params->{timestamp}));


   
  $rec->create(%$params);
}
