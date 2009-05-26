package Test::Chimps::Smoker::Git;

use strict;
use warnings;
use base qw(Test::Chimps::Smoker::Source);
__PACKAGE__->mk_ro_accessors(qw/uri/);

sub revision_after {
    my $self = shift;
    my $revision = shift;
    
# in case of the following topology:
#    H
# B1   B2
#    R
# `git log B1..H` always has B2 when `git log B2..H` always has B1
# we end up in a loop. let's use date of the current revision to
# to cut of anything older. In this case some commits in branches
# wouldn't be tested
    my $cmd = 'git log -n1 '. $revision;
    my ($date) = (`$cmd` =~ m/^date:\s*(.*)$/im);

    $cmd = "git log --reverse --since='$date' $revision..origin";
    my ($next)  = (`$cmd` =~ m/^commit\s+([a-f0-9]+)$/im);

    return $next;
}

sub committer {
    my $self = shift;
    my $revision = shift;

    my $cmd = 'git log -n1'. ($revision? " $revision" : '');
    my ($committer) = (`$cmd` =~ m/^author:\s*(.*)$/im);

    return $committer;
}

sub clone {
    my $self = shift;

# XXX: git 1.5 can not clone into dir that already exists, so we delete dir
# and clone then
    my $dir = $self->directory;
    rmdir $dir
        or die "Couldn't remove '$dir' that should be empty tmp dir created for clone: $!";
    system( qw(git clone), $self->uri, $dir ) == 0
        or die "couldn't clone ". $self->uri .": $!";

    return 1;
}

sub clean {
    my $self = shift;
    system qw(git clean -fd);
    system qw(git checkout master);
}

sub checkout {
    my $self = shift;
    my %args = @_;

    system qw(git checkout), ($args{'revision'} || 'master');
}

sub next {
    my $self = shift;

    my $revision = $self->revision_after( $self->config->{revision} );
    return () unless $revision;

    my $committer = $self->committer($revision);

    return (revision => $revision, committer => $committer);
}

1;
