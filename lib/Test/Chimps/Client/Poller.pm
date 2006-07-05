package Test::Chimps::Client::Poller;

use warnings;
use strict;

use Config;
use File::Basename;
use File::Path;
use File::Temp qw/tempdir/;
use Params::Validate qw/:all/;
use Test::Chimps::Client;
use Test::Chimps::Report;
use Test::TAP::Model::Visual;
use YAML::Syck;

=head1 NAME

Test::Chimps::Client - Poll a set of SVN repositories and run tests when they change

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module gives you everything you need to make your own build
slave.  You give it a configuration file describing all of your
projects and how to test them, and it will monitor the SVN
repositories, check the projects out (and their dependencies), test
them, and submit the report to a server.

    use Test::Chimps::Client::Poll;

    my $poller = Test::Chimps::Client::Poll->new(
      server      => 'http://www.example.com/cgi-bin/smoke-server.pl',
      config_file => '/path/to/configfile.yml'
      )

    $poller->poll();

=head1 METHODS

=head2 new ARGS

Creates a new Client object.  ARGS is a hash whose valid keys are:

=over 4

=item * config_file

Mandatory.  The configuration file describing which repositories to
monitor.  The format of the configuration is described in
L</"CONFIGURATION FILE">.

=item * server

Mandatory.  The URI of the server script to upload the reports to.

=item * simulate

Don't actually submit the smoke reports, just run the tests.  This
I<does>, however, increment the revision numbers in the config
file.

=back

=cut

use base qw/Class::Accessor/;
__PACKAGE__->mk_ro_accessors(qw/server config_file simulate/);
__PACKAGE__->mk_accessors(
  qw/_added_to_inc _env_stack _checkout_paths _config/);

# add a signal handler so destructor gets run
$SIG{INT} = sub {print "caught sigint.  cleaning up...\n"; exit(1)};

sub new {
  my $class = shift;
  my $obj = bless {}, $class;
  $obj->_init(@_);
  return $obj;
}

sub _init {
  my $self = shift;
  my %args = validate_with(params => \@_,
                           spec => 
                           { server => 1,
                             config_file => 1,
                             simulate => 0},
                           called => 'The Test::Chimps::Client::Poll constructor');
  
  foreach my $key (keys %args) {
    $self->{$key} = $args{$key};
  }
  $self->_added_to_inc([]);
  $self->_env_stack([]);
  $self->_checkout_paths([]);
  
  $self->_config(LoadFile($self->config_file));
}

sub DESTROY {
  my $self = shift;
  foreach my $tmpdir (@{$self->_checkout_paths}) {
    _remove_tmpdir($tmpdir);
  }
}

=head2 poll

Calling poll will cause the C<Poll> object to continually poll
repositories for changes in revision numbers.  If an (actual)
change is detected, the repository will be checked out (with
dependencies), built, and tested, and the resulting report will be
submitted to the server.  This method does not return.

=cut

sub poll {
  my $self = shift;
  my $config = $self->_config;
  while (1) {
    foreach my $project (keys %{$config}) {
      next if $config->{$project}->{dependency_only};
    
      my $info_out = `svn info $config->{$project}->{svn_uri}`;
      $info_out =~ m/Revision: (\d+)/;
      my $latest_revision = $1;
      $info_out =~ m/Last Changed Revision: (\d+)/;
      my $last_changed_revision = $1;
      $info_out =~ m/Last Changed Author: (\w+)/;
      my $author = $1;

      my $old_revision = $config->{$project}->{revision};

      next unless $last_changed_revision > $old_revision;

      foreach my $revision (($old_revision + 1) .. $latest_revision) {
        # only actually do the check out if the revision and last changed revision match for
        # a particular revision
        next unless _revisions_match($config->{$project}->{svn_uri}, $revision);
      
        $config->{$project}->{revision} = $revision;

        $self->_checkout_project($config->{$project}, $revision);

        my $model;
        my $durataion;
        {
          local $SIG{ALRM} = sub { die "10 minute timeout exceeded" };
          alarm 600;
          print "running tests for $project\n";
          my $start_time = time;
          eval {
            $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t t/*/t/*.t"));
          };
          $duration = time - $start_time;
          alarm 0; # cancel alarm
        }
        
        if ($@) {
          print "Tests aborted: $@\n";
        }

        $self->_unroll_env_stack;
        
        foreach my $libdir (@{$self->_added_to_inc}) {
          print "removing $libdir from \@INC\n";
          shift @INC;
        }
        $self->_added_to_inc([]);

        chdir(File::Spec->rootdir);

        foreach my $tmpdir (@{$self->_checkout_paths}) {
          _remove_tmpdir($tmpdir);
        }
        $self->_checkout_paths([]);
    
        my $report = Test::Chimps::Report->new(model => $model,
                                               report_variables =>
                                               { project => $project,
                                                 revision => $revision,
                                                 author => $author,
                                                 timestamp => scalar gmtime,
                                                 duration => $duration,
                                                 osname => $Config{osname},
                                                 osver => $Config{osver},
                                                 archname => $Config{archname}
                                               });

        my $client = Test::Chimps::Client->new(reports => [$report],
                                               server => $self->server);

        my ($status, $msg);
        if ($self->simulate) {
          $status = 1;
        } else {
          ($status, $msg) = $client->send;
        }
        
        if ($status) {
          print "Sumbitted smoke report for $project revision $revision\n";
          DumpFile($self->config_file, $config);
        } else {
          print "Error: the server responded: $msg\n";
        }
      }
    }
    sleep 60;
  }
}

sub _checkout_project {
  my $self = shift;
  my $project = shift;
  my $revision = shift;

  my $tmpdir = tempdir("chimps-svn-XXXXXXX", TMPDIR => 1);
  unshift @{$self->_checkout_paths}, $tmpdir;

  system("svn", "co", "-r", $revision, $project->{svn_uri}, $tmpdir);

  $self->_push_onto_env_stack($project->{env});

  my $projectdir = File::Spec->catdir($tmpdir, $project->{root_dir});

  if (defined $project->{dependencies}) {
    foreach my $dep (@{$project->{dependencies}}) {
      print "processing dependency $dep\n";
      $self->_checkout_project($self->_config->{$dep}, 'HEAD');
    }
  }
  
  chdir($projectdir);

  my $old_perl5lib = $ENV{PERL5LIB};
  $ENV{PERL5LIB} = join($Config{path_sep}, @{$self->_added_to_inc}) .
    ':' . $ENV{PERL5LIB};
  if (defined $project->{configure_cmd}) {
    system($project->{configure_cmd});
  }
  $ENV{PERL5LIB} = $old_perl5lib;
  
  for my $libloc (qw{blib/lib}) {
    my $libdir = File::Spec->catdir($tmpdir,
                                    $project->{root_dir},
                                    $libloc);
    print "adding $libdir to \@INC\n";
    unshift @{$self->_added_to_inc}, $libdir;
    unshift @INC, $libdir;
  }


  return $projectdir;
}

sub _remove_tmpdir {
  my $tmpdir = shift;
  print "removing temporary directory $tmpdir\n";
  rmtree($tmpdir, 0, 0);
}

sub _revisions_match {
  my $uri = shift;
  my $revision = shift;

  my $info_out = `svn info -r $revision $uri`;
  $info_out =~ m/Revision: (\d+)/;
  my $latest_revision = $1;
  $info_out =~ m/Last Changed Revision: (\d+)/;
  my $last_changed_revision = $1;

  return $latest_revision == $last_changed_revision;
}

sub _push_onto_env_stack {
  my $self = shift;
  my $vars = shift;

  my $frame = {};
  foreach my $var (keys %$vars) {
    if (exists $ENV{$var}) {
      $frame->{$var} = $ENV{$var};
    } else {
      $frame->{$var} = undef;
    }
    my $value = $vars->{$var};
    # old value substitution
    $value =~ s/\$$var/$ENV{$var}/g;

    print "setting environment variable $var to $value\n";
    $ENV{$var} = $value;
  }
  push @{$self->_env_stack}, $frame;
}

sub _unroll_env_stack {
  my $self = shift;

  while (scalar @{$self->_env_stack}) {
    my $frame = pop @{$self->_env_stack};
    foreach my $var (keys %$frame) {
      if (defined $frame->{$var}) {
        print "reverting environment variable $var to $frame->{$var}\n";
        $ENV{$var} = $frame->{$var};
      } else {
        print "unsetting environment variable $var\n";
        delete $ENV{$var};
      }
    }
  }
}

=head1 ACCESSORS

There are read-only accessors for server, config_file, simulate.

=head1 CONFIGURATION FILE

The configuration file is YAML dump of a hash.  The keys at the top
level of the hash are project names.  Their values are hashes that
comprise the configuration options for that project.

Perhaps an example is best.  A typical configuration file might
look like this:

    --- 
    Some-jifty-project: 
      configure_cmd: perl Makefile.PL --skipdeps && make
      dependencies: 
        - Jifty
      revision: 555
      root_dir: trunk/foo
      svn_uri: svn+ssh://svn.example.com/svn/foo
    Jifty: 
      configure_cmd: perl Makefile.PL --skipdeps && make
      dependencies: 
        - Jifty-DBI
      revision: 1332
      root_dir: trunk
      svn_uri: svn+ssh://svn.jifty.org/svn/jifty.org/jifty
    Jifty-DBI: 
      configure_cmd: perl Makefile.PL --skipdeps && make
      env: 
        JDBI_TEST_MYSQL: jiftydbitestdb
        JDBI_TEST_MYSQL_PASS: ''
        JDBI_TEST_MYSQL_USER: jiftydbitest
        JDBI_TEST_PG: jiftydbitestdb
        JDBI_TEST_PG_USER: jiftydbitest
      revision: 1358
      root_dir: trunk
      svn_uri: svn+ssh://svn.jifty.org/svn/jifty.org/Jifty-DBI
    
The supported project options are as follows:

=over 4

=item * configure_cmd

The command to configure the project after checkout, but before
running tests.

=item * revision

This is the last revision known for a given project.  When started,
the poller will attempt to checkout and test all revisions (besides
ones on which the directory did not change) between this one and
HEAD.  When a test has been successfully uploaded, the revision
number is updated and the configuration file is re-written.

=item * root_dir

The subdirectory inside the repository where configuration and
testing commands should be run.

=item * svn_uri

The subversion URI of the project.

=item * env

A hash of environment variable names and values that are set before
configuration, and reverted to their previous values after the
tests have been run.  In addition, if environment variable FOO's
new value contains the string "$FOO", then the old value of FOO
will be substituted in when setting the environment variable.

=item * dependencies

A list of project names that are dependencies for the given
project.  All dependencies are checked out at HEAD, have their
configuration commands run, and all dependencys' $root_dir/blib/lib
directories are added to @INC before the configuration command for
the project is run.

=item * dependency_only

Indicates that this project should not be tested.  It is only
present to serve as a dependency for another project.

=back

=head1 AUTHOR

Zev Benjamin, C<< <zev at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-chimps at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Chimps>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Chimps

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Chimps>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Chimps>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Chimps>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Chimps>

=back

=head1 ACKNOWLEDGEMENTS

The code in this distribution is based on smokeserv-client.pl and
smokeserv-server.pl from the PUGS distribution.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Zev Benjamin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
