#!/usr/bin/env perl

use warnings;
use strict;

use Test::Chimps::Smoker;
use File::Spec;
use Getopt::Long;
use Pod::Usage;

my $server;
my $config_file = File::Spec->catfile($ENV{HOME}, 'smoker-config.yml');
my $iterations = 'inf';
my $projects = 'all';
my $help = 0;
my $jobs = 1;
my $sleep = 60;

GetOptions(
    "server|s=s",      \$server,
    "config_file|c=s", \$config_file,
    "iterations|i=i",  \$iterations,
    "projects|p=s",    \$projects,
    "help|h",          \$help,
    "jobs|j=i",        \$jobs,
    "sleep=i",         \$sleep,
) || pod2usage(-exitval => 2, -verbose => 1);


if ($help) {
  pod2usage(-exitval => 1,
            -verbose => 2,
            -noperldoc => 1);
}

unless ( defined $server ) {
  print "No server specified, simulation mode enabled\n";
}

if ($projects ne 'all') {
  $projects = [split /,/, $projects];
}

my $poller = Test::Chimps::Smoker->new(
  server      => $server,
  config_file => $config_file,
  jobs        => $jobs,
  sleep       => $sleep,
);

$poller->smoke(
  iterations => $iterations,
  projects => $projects,
);
  
__DATA__

=head1 NAME

chimps-smoker.pl - continually smoke projects

=head1 SYNOPSIS

chimps-smoker.pl --server SERVER --config_file CONFIG_FILE
    [--iterations N] [--projects PROJECT1,PROJECT2,... ] [--jobs N]
    [--sleep N]

This program is a wrapper around Test::Chimps::Smoker, which allows
you to specify common options on the command line.

=head1 ARGUMENTS

=head2 --config_file, -c

Specifies the path to the configuration file.  For more information
about the configuration file format, see L<Test::Chimps::Smoker>.

=head2 --server, -s

Specifies the full path to the chimps server CGI. Reports are not sent
anywhere if it's not provided.

=head1 OPTIONS

=head2 --iterations, -i

Specifies the number of iterations to run.  This is the number of
smoke reports to generate per project.  A value of 'inf' means to
continue smoking forever.  Defaults to 'inf'.

=head2 --projects, -p

A comma-separated list of projects to smoke.  If the string 'all'
is provided, all projects will be smoked.  Defaults to 'all'.

=head2 --jobs, -j

The number of parallel processes to use when running tests.

=head2 --sleep

The number of seconds smoker should sleep between checks for updates.
Defaults to 60 seconds.

=head1 AUTHOR

Zev Benjamin C<< zev at cpan.org >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Best Practical Solutions.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
