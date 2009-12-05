package Test::Chimps::Smoker::Source;

use strict;
use warnings;
use base qw/Class::Accessor/;
use Scalar::Util qw(weaken);
use Params::Validate qw/:all/;
use File::Temp qw/tempdir/;
use File::Path;

__PACKAGE__->mk_ro_accessors(qw/smoker/);
__PACKAGE__->mk_ro_accessors(
    qw/
        name
        configure_cmd
        root_dir
        repository
        env
        dependencies
        dependency_only
        test_glob
        libs
        clean_cmd
        jobs
        /
);
__PACKAGE__->mk_accessors(qw/revision directory cloned cleaner/);

sub new {
    my $proto = shift;
    my %args = @_;
    my $type = delete $args{'type'} or die "No type of a source repository";

    my $class = ref($proto) || $proto;
    $class =~ s/[^:]*$/$type/;

    eval "require $class; 1" or die "Couldn't load $class: $@";

    my $config = delete $args{config};
    my $obj = bless { %args }, $class;
    weaken $obj->{'smoker'};
    return $obj->_init( %{$config} );
}

sub _init {
    my $self = shift;
    my %args = validate_with(
        params => \@_,
        called => 'The Test::Chimps::Smoker::Source constructor',
        spec   => {
            name            => 1,
            configure_cmd   => 0,
            revision        => 0,
            root_dir        => { default => "." },
            repository      => 1,
            env             => { type => HASHREF, default => {} },
            dependencies    => { type => ARRAYREF, default => [] },
            dependency_only => 0,
            test_glob => { default => 't/*.t t/*/t/*.t' },
            libs      => { type    => ARRAYREF, default => [] },
            clean_cmd => 0,
            jobs      => 0,
        }
    );
    $self->{$_} = $args{$_} for keys %args;
    return $self;
}

sub do_clone {
    my $self = shift;
    if ( $self->cloned ) {
        $self->chdir;
        return 1;
    }

    my $tmpdir = tempdir("chimps-@{[$self->name]}-XXXX", TMPDIR => 1);
    $self->directory( $tmpdir );
    $self->chdir;
    $self->clone;

    $self->cloned(1);

    return 1;
}

sub do_checkout {
    my $self = shift;
    my $revision = shift;

    $self->chdir;
    $self->checkout( $revision );

    my $projectdir = File::Spec->catdir($self->directory, $self->root_dir);

    my @libs = map File::Spec->catdir($projectdir, $_),
      'blib/lib', @{ $self->libs };

    my @otherlibs;
    foreach my $dep (@{$self->dependencies}) {
        print "processing dependency $dep\n";
        my $other = $self->smoker->source($dep);
        $other->do_clone;
        my @deplibs = $other->do_checkout;
        if (@deplibs) {
            push @otherlibs, @deplibs;
        } else {
            print "Dependency $dep failed; aborting";
            return ();
        }
    }

    $self->smoker->_push_onto_env_stack({
        %{$self->env},
        'CHIMPS_'. uc($self->name) .'_ROOT' => $projectdir,
    });

    my %seen;
    @libs = grep {not $seen{$_}++} @libs, @otherlibs;

    $self->chdir($self->root_dir);

    local $ENV{PERL5LIB} = join(":",@libs,$ENV{PERL5LIB});

    if (defined( my $cmd = $self->configure_cmd )) {
        my $ret = system($cmd);
        if ($ret) {
            print STDERR "Return value of $cmd from $projectdir = $ret\n"
                if $ret;
            return ();
        }
    }

    if (defined( my $cmd = $self->clean_cmd )) {
        print "Going to run project cleaner '$cmd'\n";
        my @args = (
            '--project', $self->name,
            '--config', $self->smoker->config_file,
        );
        open my $fh, '-|', join(' ', $cmd, @args)
            or die "Couldn't run `". join(' ', $cmd, @args) ."`: $!";
        $self->cleaner( do { local $/; <$fh> } );
        close $fh;
    }
    return @libs;
}

sub do_clean {
    my $self = shift;
    $self->chdir;

    if (defined( my $cmd = $self->clean_cmd )) {
        my @args = (
            '--project', $self->name,
            '--config', $self->smoker->config_file,
            '--clean',
        );
        open my $fh, '|-', join(' ', $cmd, @args)
            or die "Couldn't run `". join(' ', $cmd, @args) ."`: $!";
        print $fh $self->cleaner;
        close $fh;
    }

    $self->clean;

    foreach my $dep (@{$self->dependencies}) {
        $self->smoker->source( $dep )->do_clean;
    }
}

sub remove_checkout {
    my $self = shift;
    return unless $self->cloned;

    my $dir = $self->directory;
    print "removing temporary directory $dir\n";
    rmtree($dir, 0, 0);
    $self->directory(undef);
    $self->cloned(0);
}

sub clone { return 1 }
sub checkout { return 1 }
sub clean { return 1 }

sub next { return () }

sub run_cmd {
    my $self = shift;
    my @args = @_;
    system(@args) == 0
        or die "Couldn't run `". join(' ', @args ) ."`: $!";
    return 1;
}

sub chdir {
    my $self = shift;
    my $sub = shift;
    my $dir = $self->directory;
    if ( defined $sub && length $sub ) {
        $dir = File::Spec->catdir( $dir, $sub );
    }
    CORE::chdir($dir)
        or die "Couldn't change dir to '$dir': $!";
}


=head2 OPTIONS

The following configuration options can be set on a per-projet basis,
and have accessors on the object:

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

=item * repository

A hash describing repository of the project. Mandatory key is
type which must match a source class name, for example SVN or
Git. Particular source class may have more options, but at this
moment Git and SVN have only 'uri' option.

=item * env

A hash of environment variable names and values that are set before
configuration, and reverted to their previous values after the
tests have been run.  In addition, if environment variable FOO's
new value contains the string "$FOO", then the old value of FOO
will be substituted in when setting the environment variable.

Special environment variables are set in addition to described
above. For each project CHIMPS_<project name>_ROOT is set pointing
to the current checkout of the project.

=item * dependencies

A list of project names that are dependencies for the given
project.  All dependencies are checked out at HEAD, have their
configuration commands run, and all dependencys' $root_dir/blib/lib
directories are added to @INC before the configuration command for
the project is run.

=item * dependency_only

Indicates that this project should not be tested.  It is only
present to serve as a dependency for another project.

=item * test_glob

How to find all your tests, defaults to
t/*.t t/*/t/*.t

=item * libs

A list of paths, relative to the project root, which should be added
to @INC.  C<blib/lib> is automatically added, but you may need to
include C<lib> here, for instance.

=item * clean_cmd

The command to clean before or after each iteration of the project testing.
Called B<twice> before running tests and after with --config, --project
arguments and --clean argument when called for the second time after testing.

When called before testing (without --clean), state information can be printed
to STDOUT. Later when called after testing (with --clean), the state info can
be read from STDIN.

An example you can find in a tarball of this distribution - F<examples/pg_dbs_cleaner.pl>.

=item * jobs

The number of parallel test processes to run.  If not specified, uses
the value set on the smoker.

=cut

1;
