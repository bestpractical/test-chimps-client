#!/usr/bin/env perl

use warnings;
use strict;

use Config;
use Test::Chimps::Report;
use Test::Chimps::Client;
use Test::TAP::Model::Visual;
use YAML::Syck;
use File::Basename;
use File::Temp qw/tempdir/;
use File::Path;

our $config = LoadFile("/home/zev/bps/poll-config.yml");

our @added_to_inc;
our @added_to_env;
our @checkout_paths;

END {
  foreach my $tmpdir (@checkout_paths) {
    remove_tmpdir($tmpdir);
  }
}

while (1) {
  foreach my $project (keys %{$config}) {
    next if $config->{$project}->{dependency_only};
    
    my $info_out = `svn info $config->{$project}->{svn_uri}`;
    $info_out =~ m/Revision: (\d+)/;
    my $latest_revision = $1;
    $info_out =~ m/Last Changed Author: (\w+)/;
    my $author = $1;

    my $old_revision = $config->{$project}->{revision}

    next unless $latest_revision > $old_revision;

    foreach my $revision (($old_revision + 1) .. $revision) {
      $config->{$project}->{revision} = $revision;

      checkout_project($config->{$project}, $revision);
    
      my $start_time = time;
      my $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t t/*/t/*.t"));
      my $duration = time - $start_time;

      foreach my $var (@added_to_env) {
        print "unsetting environment variable $var\n";
        delete $ENV{$var};
      }
      @added_to_env = ();

      foreach my $libdir (@added_to_inc) {
        print "removing $libdir from \@INC\n";
        shift @INC;
      }
      @added_to_inc = ();

      chdir(File::Spec->rootdir);

      foreach my $tmpdir (@checkout_paths) {
        remove_tmpdir($tmpdir);
      }
      @checkout_paths = ();
    
      my $report = Test::Smoke::Report->new(model => $model,
                                            extra_data =>
                                            { category => $project,
                                              subcategory => 'repository snapshot / ' . $config{osname},
                                              project => scalar fileparse($config->{$project}->{svn_uri}),
                                              revision => $revision,
                                              author => $author,
                                              timestamp => scalar gmtime,
                                              duration => $duration});

      my $client = Test::Smoke::Report::Client->new(reports => [$report],
                                                    server => 'http://galvatron.mit.edu/cgi-bin/report_server.pl');

      my ($status, $msg) = $client->send;

      if ($status) {
        print "Sumbitted smoke report for $project revision $revision\n";
        DumpFile("/home/zev/bps/poll-config.yml", $config);
      } else {
        print "Error: the server responded: $msg\n";
      }
    }
  }
  sleep 60;
}

sub checkout_project {
  my $project = shift;
  my $revision = shift;

  my $tmpdir = tempdir("smoke-svn-XXXXXXX", TMPDIR => 1);
  unshift @checkout_paths, $tmpdir;

  system("svn", "co", "-r", $revision, $project->{svn_uri}, $tmpdir);

  if (defined $project->{env}) {
    foreach my $var (keys %{$project->{env}}) {
      unshift @added_to_env, $var;
      print "setting environment variable $var to $project->{env}->{$var}\n";
      $ENV{$var} = $project->{env}->{$var};
    }
  }

  my $projectdir = File::Spec->catdir($tmpdir, $project->{root_dir});

  if (defined $project->{dependencies}) {
    foreach my $dep (@{$project->{dependencies}}) {
      print "processing dependency $dep\n";
      checkout_project($config->{$dep});
    }
  }
  
  chdir($projectdir);

  if (defined $project->{configure_cmd}) {
    system($project->{configure_cmd});
  }

  for my $libloc (qw{blib/lib}) {
    my $libdir = File::Spec->catdir($tmpdir,
                                    $project->{root_dir},
                                    $libloc);
    print "adding $libdir to \@INC\n";
    unshift @added_to_inc, $libdir;
    unshift @INC, $libdir;
  }


  return $projectdir;
}

sub remove_tmpdir {
  my $tmpdir = shift;
  print "removing temporary directory $tmpdir\n";
  rmtree($tmpdir, 0, 0);
}
