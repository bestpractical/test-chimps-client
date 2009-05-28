package Test::Chimps::TestSVN;

use strict;
use warnings;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(directory));

use File::Spec;
use File::Temp qw(tempdir);
use Test::Chimps::TestUtils qw(write_file run_cmd);


sub new {
    my $proto = shift;
    my $self = bless { @_ }, ref($proto) || $proto;
    return $self->init;
}

sub init {
    my $self = shift;

    my $dir = tempdir(CLEANUP => 1)
        or die "Couldn't create a temp directory";

    system('svnadmin', 'create', $dir) == 0
        or die "couldn't create a svn reposiotry";

    $self->directory( $dir );

    return $self;
}

sub uri { return "file://". $_[0]->directory }

sub checkout {
    my $self = shift;

    my $uri = $self->uri;

    my $co_dir = File::Temp->newdir;
    Test::More::diag("Created a dir for checkout: $co_dir");
    system('svn', 'checkout', $uri, $co_dir) == 0
        or die "couldn't checkout repository '$uri' into '$co_dir': $!";

    return $co_dir;
}

sub create {
    my $self = shift;
    my $package = shift || 'T';

    my $co_dir = $self->checkout;

    write_file( $co_dir, 'Makefile.PL', <<END
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME            => '$package',
    VERSION_FROM    => '$package.pm',
);
END
    );

    write_file( $co_dir, $package .'.pm', <<END
package $package;
our \$VERSION = '0.01';
1;
END
    );

    write_file( File::Spec->catdir($co_dir, 't'), 'basic.t', <<END
use Test::More tests => 1;
ok 1, "basic test";
END
    );

    run_cmd('svn', 'add', File::Spec->catfile($co_dir, 'Makefile.PL'));
    run_cmd('svn', 'add', File::Spec->catfile($co_dir, $package .'.pm'));
    run_cmd('svn', 'add', File::Spec->catdir($co_dir, 't'));
    run_cmd('svn', 'commit', '-m', 'first commit', $co_dir);

    return 1;
}

sub update {
    my $self = shift;

    my ($fdir, $fname, $content) = @_;

    my $co_dir = $self->checkout;

    write_file( File::Spec->catdir($co_dir, $fdir), $fname, $content );
    run_cmd('svn', 'add', File::Spec->catfile($co_dir, $fdir, $fname));
    run_cmd('svn', 'commit', '-m', 'a commit', $co_dir);
    return 1;
}

1;
