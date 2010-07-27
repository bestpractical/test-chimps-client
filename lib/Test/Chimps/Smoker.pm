package Test::Chimps::Smoker;

use warnings;
use strict;

use Config;
use Cwd qw(abs_path);
use Params::Validate qw/:all/;
use Test::Chimps::Smoker::Source;
use Test::Chimps::Client;
use TAP::Harness::Archive;
use YAML::Syck;

=head1 NAME

Test::Chimps::Smoker - Poll a set of repositories and run tests when they change

=head1 SYNOPSIS

    # command line tool
    chimps-smoker.pl \
        -c /path/to/configfile.yml \
        -s http://www.example.com/cgi-bin/chimps-server.pl

    # API
    use Test::Chimps::Smoker;

    my $poller = Test::Chimps::Smoker->new(
        server      => 'http://www.example.com/cgi-bin/chimps-server.pl',
        config_file => '/path/to/configfile.yml',
    );

    $poller->smoke;

=head1 DESCRIPTION

Chimps is the Collaborative Heterogeneous Infinite Monkey
Perfectionification Service.  It is a framework for storing,
viewing, generating, and uploading smoke reports.  This
distribution provides client-side modules and binaries for Chimps.

This module gives you everything you need to make your own build
slave.  You give it a configuration file describing all of your
projects and how to test them, and it will monitor the repositories,
check the projects out (and their dependencies), test them, and submit
the report to a server.

=head1 METHODS

=head2 new ARGS

Creates a new smoker object.  ARGS is a hash whose valid keys are:

=over 4

=item * config_file

Mandatory.  The configuration file describing which repositories to
monitor.  The format of the configuration is described in
L</"CONFIGURATION FILE">. File is update after each run.

=item * server

Optional.  The URI of the server script to upload the reports to.
Defaults to simulation mode when reports are sent.

=item * sleep

Optional.  Number of seconds to sleep between repository checks.
Defaults to 60 seconds.

=item * jobs

Optional.  Number of test jobs to run in parallel.  Defaults to 1.

=back

=cut

use base qw/Class::Accessor/;
__PACKAGE__->mk_ro_accessors(qw/server config_file sleep jobs/);
__PACKAGE__->mk_accessors(
    qw/_env_stack sources config/);

# add a signal handler so destructor gets run
$SIG{INT} = sub {print "caught sigint.  cleaning up...\n"; exit(1)};
$ENV{PERL5LIB} = "" unless defined $ENV{PERL5LIB}; # Warnings avoidance

sub new {
    my $class = shift;
    my $obj = bless {}, $class;
    $obj->_init(@_);
    return $obj;
}

sub _init {
    my $self = shift;
    my %args = validate_with(
        params => \@_,
        spec   => {
            config_file => 1,
            server      => 0,
            jobs => {
                optional => 1,
                type     => SCALAR,
                regex    => qr/^\d+$/,
                default  => 1,
              },
            sleep => {
                optional => 1,
                type     => SCALAR,
                regex    => qr/^\d+$/,
                default  => 60,
              },
          },
        called => 'The Test::Chimps::Smoker constructor'
      );

    foreach my $key (keys %args) {
        $self->{$key} = $args{$key};
    }

    # make it absolute so we can update it later from any dir we're in
    $self->{'config_file'} = abs_path($self->{'config_file'});

    $self->_env_stack([]);
    $self->sources({});

    $self->load_config;
}

=head2 smoke PARAMS

Calling smoke will cause the C<Smoker> object to continually poll
repositories for changes in revision numbers.  If an (actual)
change is detected, the repository will be checked out (with
dependencies), built, and tested, and the resulting report will be
submitted to the server.  This method may not return.  Valid
options to smoke are:

=over 4

=item * iterations

Specifies the number of iterations to run.  This is the number of
smoke reports to generate per project.  A value of 'inf' means to
continue smoking forever.  Defaults to 'inf'.

=item * projects

An array reference specifying which projects to smoke.  If the
string 'all' is provided instead of an array reference, all
projects will be smoked.  Defaults to 'all'.

=back

=cut

sub smoke {
    my $self = shift;
    my $config = $self->config;

    my $dir = Cwd::getcwd;

    my %args = validate_with(
        params => \@_,
        spec   => {
            iterations => {
                optional => 1,
                type     => SCALAR,
                regex    => qr/^(inf|\d+)$/,
                default  => 'inf'
              },
            projects => {
                optional => 1,
                type     => ARRAYREF | SCALAR,
                default  => 'all'
              }
          },
        called => 'Test::Chimps::Smoker->smoke'
      );

    my $projects = $args{projects};
    my $iterations = $args{iterations};
    $self->_validate_projects_opt($projects);

    if ($projects eq 'all') {
        $projects = [keys %$config];
    }

    $self->_smoke_n_times($iterations, $projects);
    chdir $dir;
}

sub _validate_projects_opt {
    my ($self, $projects) = @_;
    return if $projects eq 'all';

    foreach my $project (@$projects) {
        die "no such project: '$project'"
          unless exists $self->config->{$project};
    }
}

sub _smoke_n_times {
    my $self = shift;
    my $n = shift;
    my $projects = shift;

    if ($n <= 0) {
        die "Can not smoke projects a negative number of times";
    } elsif ($n eq 'inf') {
        while (1) {
            $self->_smoke_projects($projects);
            CORE::sleep $self->sleep if $self->sleep;
        }
    } else {
        for (my $i = 0; $i < $n; $i++) {
            $self->_smoke_projects($projects);
            CORE::sleep $self->sleep if $i+1 < $n && $self->sleep;
        }
    }
}

sub _smoke_projects {
    my $self = shift;
    my $projects = shift;

    foreach my $project (@$projects) {
        local $@;
        eval { $self->_smoke_once($project) };
        warn "Couldn't smoke project '$project': $@"
            if $@;
    }
}

sub _smoke_once {
    my $self = shift;
    my $project = shift;

    my $source = $self->source($project);
    return 1 if $source->dependency_only;

    $source->do_clone;

    my %next = $source->next;
    return 0 unless keys %next;

    my $revision = $next{'revision'};

    my @libs = $source->do_checkout($revision);
    unless (@libs) {
        print "Skipping report for $project revision $revision due to build failure\n";
        $self->update_revision_in_config( $project => $revision );
        return 0;
    }

    print "running tests for $project\n";
    my $test_glob = $source->test_glob;
    my $tmpfile = File::Temp->new( TEMPLATE => "chimps-archive-XXXXX", SUFFIX => ".tar.gz" );
    my $harness = TAP::Harness::Archive->new( {
            archive          => $tmpfile,
            extra_properties => {
                project   => $project,
                revision  => $revision,
                committer => $next{'committer'},
                committed_date => $next{'committed_date'},
                osname    => $Config{osname},
                osvers    => $Config{osvers},
                archname  => $Config{archname},
              },
            jobs => ($source->jobs || $self->jobs),
            lib => \@libs,
        } );
    {
        # Runtests apparently grows PERL5LIB -- local it so it doesn't
        # grow without bound
        local $ENV{PERL5LIB} = $ENV{PERL5LIB};
        $harness->runtests(glob($test_glob));
    }

    $source->do_clean;

    $self->_unroll_env_stack;

    if ( my $server = $self->server ) {
        my $client = Test::Chimps::Client->new(
            archive => $tmpfile, server => $server,
        );

        print "Sending smoke report for $server\n";
        my ($status, $msg) = $client->send;
        unless ( $status ) {
            print "Error: the server responded: $msg\n";
            return 0;
        }
    }
    else {
        print "Server is not specified, don't send the report\n";
    }

    print "Done smoking revision $revision of $project\n";
    $self->update_revision_in_config( $project => $revision );
    return 1;
}

sub load_config {
    my $self = shift;

    my $cfg = $self->config(LoadFile($self->config_file));

    # update old style config file
    {
        my $found_old_style = 0;
        foreach ( grep $_->{svn_uri}, values %$cfg ) {
            $found_old_style = 1;

            $_->{'repository'} = {
                type => 'SVN',
                uri  => delete $_->{svn_uri},
            };
        }
        DumpFile($self->config_file, $cfg) if $found_old_style;
    }
    
    # store project name in its hash
    $cfg->{$_}->{'name'} = $_ foreach keys %$cfg;
}

sub update_revision_in_config {
    my $self = shift;
    my ($project, $revision) = @_;

    $revision = $self->source($project)->store_tested_revision($revision);

    my $tmp = LoadFile($self->config_file);
    $tmp->{$project}->{revision} = $self->config->{$project}->{revision} = $revision;
    $self->source($project)->revision($revision);
    DumpFile($self->config_file, $tmp);
}

sub source {
    my $self = shift;
    my $project = shift;
    $self->sources->{$project} ||= Test::Chimps::Smoker::Source->new(
            %{ $self->config->{$project}{'repository'} },
            config => $self->config->{$project},
            smoker => $self,
        );
    return $self->sources->{$project};
}

sub _push_onto_env_stack {
    my $self = shift;
    my $vars = shift;

    my @with_subst = ();

    my $frame = {};
    while ( my ($var, $value) = each %$vars ) {
        if (exists $ENV{$var}) {
            $frame->{$var} = $ENV{$var};
        } else {
            $frame->{$var} = undef;
        }

        # old value substitution
        if ( $value =~ /\$/ ) {
            push @with_subst, $var;
            next;
        }

        print "setting environment variable $var to $value\n";
        $ENV{$var} = $value;
    }

    for my $var (@with_subst) {
        my $value = $vars->{$var};
        while ( my ($use) = ($value =~ /\$(\S+)/) ) {
            $value =~ s/\$\Q$use/$ENV{$use}/ge;
        }
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

sub DESTROY {
    my $self = shift;
    $_->remove_checkout for grep defined, values %{ $self->sources };
}

=head1 ACCESSORS

There are read-only accessors for server and config_file.

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
      repository:
        type: SVN
        uri: svn+ssh://svn.example.com/svn/foo
      test_glob: t/*.t t/*/*.t
    Jifty:
      configure_cmd: perl Makefile.PL --skipdeps && make
      dependencies:
        - Jifty-DBI
      revision: 1332
      root_dir: trunk
      repository:
        type: SVN
        uri: svn+ssh://svn.jifty.org/svn/jifty.org/jifty
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
      repository:
        type: SVN
        uri: svn+ssh://svn.jifty.org/svn/jifty.org/Jifty-DBI

See L<Test::Chimps::Smoker::Source> for a list of project options.

=head1 REPORT VARIABLES

This module assumes the use of the following report variables:

    project
    revision
    committer
    duration
    osname
    osvers
    archname

=head1 AUTHOR

Zev Benjamin, C<< <zev at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-chimps at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Chimps-Client>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Chimps::Smoker

You can also look for information at:

=over 4

=item * Mailing list

Chimps has a mailman mailing list at
L<chimps@bestpractical.com>.  You can subscribe via the web
interface at
L<http://lists.bestpractical.com/cgi-bin/mailman/listinfo/chimps>.

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Chimps-Client>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Chimps-Client>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Chimps-Client>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Chimps-Client>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2006-2009 Best Practical Solutions.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
