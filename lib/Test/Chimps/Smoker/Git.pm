package Test::Chimps::Smoker::Git;

use strict;
use warnings;
use base qw(Test::Chimps::Smoker::Source);
__PACKAGE__->mk_ro_accessors(qw/uri branch/);


sub _init {
    my $self = shift;
    $self->{'branch'} ||= 'master';
    return $self->SUPER::_init( @_ );
}

sub committer {
    my $self = shift;
    my $revision = shift;

    my $cmd = 'git log -n1'. ($revision? " $revision" : '');
    my ($committer) = (`$cmd` =~ m/^author:\s*(.*)$/im);

    return $committer;
}

sub committed_date {
    my $self = shift;
    my $revision = shift;

    my $cmd = 'git log -n1 --pretty=fuller'. ($revision? " $revision" : '');
    my ($date) = (`$cmd` =~ m/^commitdate:\s*(.*?)\s*$/im);

    return $date;
}

sub clone {
    my $self = shift;

# XXX: git 1.5 can not clone into dir that already exists, so we delete dir
# and clone then
    my $dir = $self->directory;
    chdir "$dir/.." or die "Couldn't change dir to parent of $dir: $!";
    rmdir $dir
        or die "Couldn't remove '$dir' that should be empty tmp dir created for clone: $!";
    $self->run_cmd( qw(clone), $self->uri, $dir );
    $self->chdir;

    # execute this manually since Chimps will die if system
    # doesn't return 0 and we're actually expecting this to 
    # fail and return 0 in repos with multiple branches
    my $cmd = 'git rev-parse -q --verify '.$self->branch;
    my $local_branch = `$cmd`;
    unless ( $local_branch ) {
        # old gits (like the one on smoke) need -b with -t
        $self->run_cmd( 'checkout', '-t', '-b', $self->branch, 'origin/'.$self->branch );
    }

    unless ($self->revision) {
        # Default is that we've tested all parents of the current
        # revision, but not the current revision itself.
        my $branch = $self->branch;
        my $rev = `git log $branch --pretty='format:\%P' -n 1`; chomp $rev;
        $self->revision($rev);
    }

    return 1;
}

sub clean {
    my $self = shift;
    $self->run_cmd(qw(clean -fxdq));
    $self->run_cmd('checkout', 'HEAD', '.');
}

sub checkout {
    my $self = shift;
    my $revision = shift;

    $self->run_cmd(qw(checkout), $revision || $self->branch);
}

sub next {
    my $self = shift;

    # Get more revisions
    `git remote update 2>&1`;

    # In rev-list terms, "everything that isn't these commit, or an
    # ancestor of them"
    my $branch = $self->branch;
    my @seen = map {"^$_"} split ' ', $self->revision;
    my @revs = split /\n/, `git rev-list refs/remotes/origin/$branch @seen`;

    return () unless @revs;

    my $rev = pop @revs;
    return (
        revision       => $rev,
        committer      => $self->committer($rev),
        committed_date => $self->committed_date($rev),
    );
}

sub store_tested_revision {
    my $self = shift;
    my $ref = shift;
    my @oldrefs = split ' ', $self->revision;
    my $branch = $self->branch;

    # Drop anything which is a parent of what we've tested.
    my %parents;
    my @commits = split /\n/, `git rev-list --parents $ref @oldrefs`;
    $parents{$_} = 1 for map {my($sha,@parents) = split; @parents} @commits;
    return join(" ", grep {not $parents{$_}} $ref, @oldrefs);
}

sub run_cmd {
    my $self = shift;
    return $self->SUPER::run_cmd( "git", @_ );
}

1;
