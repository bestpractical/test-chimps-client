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

sub is_change_on_revision {
    my $self = shift;
    my ($latest_revision, $last_changed) = $self->revision_info(@_);
    return $latest_revision == $last_changed;
}

sub checkout {
    my $self = shift;
    my %args = @_;

    system("svn", "co", "-r", $args{'revision'}, $self->uri, $self->directory);
}

sub next {
    my $self = shift;
    my ($latest_revision, $last_changed_revision) = $self->revision_info;

    my $old_revision = $self->config->{revision};

    return () unless $last_changed_revision > $old_revision;

    my @revisions = (($old_revision + 1) .. $latest_revision);
    my $revision;
    while (@revisions) {
        $revision = shift @revisions;

# only actually do the check out if the revision and last changed revision match for
# a particular revision
        last if $self->is_change_on_revision($revision);
    }
    return () unless $revision;

    my $committer = $self->committer($revision);


    return (revision => $revision, committer => $committer);
}

1;
