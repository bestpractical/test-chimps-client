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
L</CONFIGURATION FILE>.

=item * server

Mandatory.  The URI of the server script to upload the reports to.

=item * simulate

Don't actually submit the smoke reports, just run the tests.  This
I<does>, however, increment the revision numbers in the config
file.

=back

=cut

use base qw/Class::Accessor/;
Test::Chimps::Client::Poller->mk_ro_accessors(qw/server config_file simulate/);
Test::Chimps::Client::Poller->mk_accessors(
  qw/_added_to_inc _added_to_env _checkout_paths _config/);

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
  $self->_added_to_env([]);
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

        print "running tests for $project\n";
        my $start_time = time;
        my $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t t/*/t/*.t"));
        my $duration = time - $start_time;

        foreach my $var (@{$self->_added_to_env}) {
          print "unsetting environment variable $var\n";
          delete $ENV{$var};
        }
        $self->_added_to_env([]);

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
                                               { category => $project,
                                                 subcategory => 'repository snapshot / ' . $Config{osname},
                                                 project => scalar fileparse($config->{$project}->{svn_uri}),
                                                 revision => $revision,
                                                 author => $author,
                                                 timestamp => scalar gmtime,
                                                 duration => $duration});

        my $client = Test::Chimps::Client->new(reports => [$report],
                                               server => 'http://galvatron.mit.edu/cgi-bin/report_server.pl');

        my ($status, $msg);
        if ($self->simulate) {
          $status = 1;
        } else {
          ($status, $msg) = $client->send;
        }
        
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
}

sub _checkout_project {
  my $self = shift;
  my $project = shift;
  my $revision = shift;

  my $tmpdir = tempdir("chimps-svn-XXXXXXX", TMPDIR => 1);
  unshift @{$self->_checkout_paths}, $tmpdir;

  system("svn", "co", "-r", $revision, $project->{svn_uri}, $tmpdir);

  if (defined $project->{env}) {
    foreach my $var (keys %{$project->{env}}) {
      unshift @{$self->_added_to_env}, $var;
      print "setting environment variable $var to $project->{env}->{$var}\n";
      $ENV{$var} = $project->{env}->{$var};
    }
  }

  my $projectdir = File::Spec->catdir($tmpdir, $project->{root_dir});

  if (defined $project->{dependencies}) {
    foreach my $dep (@{$project->{dependencies}}) {
      print "processing dependency $dep\n";
      $self->_checkout_project($self->_config->{$dep}, 'HEAD');
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


1;
