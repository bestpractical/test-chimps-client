package Test::Chimps::Smoker::SVN;

use strict;
use warnings;
use base qw(Test::Chimps::Smoker::Source);
__PACKAGE__->mk_ro_accessors(qw/uri/);

sub revision_info {
    my $self = shift;
    my $revision = shift;

    my $cmd = 'svn info'. ($revision? " -r $revision" : '') .' '. $self->uri;

    my $info_out = `$cmd`;
    my ($latest_revision) = ($info_out =~ m/^Revision: (\d+)/m);
    my ($last_changed)    = ($info_out =~ m/^Last Changed Rev: (\d+)/m);
    my ($committer)       = ($info_out =~ m/^Last Changed Author: (\w+)/m);

    return ($latest_revision, $last_changed, $committer);
}

sub committer {
    my $self = shift;
    return ($self->revision_info( @_ ))[2];
}

sub checkout {
    my $self = shift;
    my %args = @_;

    unless ( -e '.svn' ) {
        $self->run_cmd("checkout", "-r", ($args{'revision'} || 'HEAD'), $self->uri, $self->directory);
    }
    else {
        $self->run_cmd("update", "-r", ($args{'revision'} || 'HEAD'), $self->directory);
    }
}

sub clean {
    my $self = shift;
    return $self->run_cmd(qw(revert -R .));
}

sub next {
    my $self = shift;

    my $revision = $self->config->{revision};
    my $cmd = "svn log --limit 1 -q -r ". ($revision+1) .":HEAD ". $self->uri;
    my ($next, $committer) = (`$cmd` =~ m/^r([0-9]+)\s+\|\s*(.*?)\s*\|/m);
    return () unless $next;

    return (revision => $next, committer => $committer);
}

sub run_cmd {
    my $self = shift;
    my @args = @_;
    system("svn", @args) == 0
        or die "Couldn't run `". join(' ', "svn", @args ) ."`: $!";
    return 1;
}

1;
