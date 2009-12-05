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

sub revision_after {
    my $self = shift;
    my $revision = shift;

    # stolen shamelessly from post-receive-email
    # this probably still loops and needs some date support
    # or a stash or shas to test
    my $branch = $self->branch;
    my $cmd = "git rev-parse --not --branches | grep -v \$(git rev-parse $branch) | git rev-list --stdin $revision..origin/$branch | tail -n 1";
    my $next = `$cmd`;
    chomp($next);

    return $next;
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

    my $cmd = 'git log -n1'. ($revision? " $revision" : '');
    my ($date) = (`$cmd` =~ m/^date:\s*(.*?)\s*$/im);

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

    $self->revision($self->branch . "^") unless $self->revision;

    return 1;
}

sub clean {
    my $self = shift;
    $self->run_cmd(qw(clean -fd));
    $self->run_cmd('checkout', $self->branch);
}

sub checkout {
    my $self = shift;
    my %args = @_;

    $self->run_cmd(qw(checkout), ($args{'revision'} || $self->branch));
}

sub next {
    my $self = shift;

    my $current = $self->revision;

    my $revision = $self->revision_after( $current );
    unless ( $revision ) {
        $self->run_cmd('pull');
        $revision = $self->revision_after( $current );
        return () unless $revision;
    }

    my $committer = $self->committer($revision);
    my $committed_date = $self->committed_date($revision);

    return (
        revision       => $revision,
        committer      => $committer,
        committed_date => $committed_date,
    );
}

sub run_cmd {
    my $self = shift;
    return $self->SUPER::run_cmd( "git", @_ );
}

1;
