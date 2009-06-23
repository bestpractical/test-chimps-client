package Test::Chimps::Smoker::SVN;

use strict;
use warnings;
use base qw(Test::Chimps::Smoker::Source);
__PACKAGE__->mk_ro_accessors(qw/uri/);

use File::Path qw(remove_tree);

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
    $self->run_cmd(qw(revert -R .));

    open my $status_fh, "-|", qw(svn status .)
        or die "Can't call program `svn status .`: $!";
    while ( my $s = <$status_fh> ) {
        next unless my ($path) = ($s =~ /^\?\s*(.*)$/);
        remove_tree( File::Spec->catdir($self->directory, $path) );
    }
}

sub next {
    my $self = shift;

    my $revision = $self->config->{revision};
    my $cmd = "svn log --limit 1 -q -r ". ($revision+1) .":HEAD ". $self->uri;
    my ( $next, $committer, $committed_date ) =
      ( `$cmd` =~ m/^r([0-9]+)\s+\|\s*(.*?)\s*\|\s*([^(]*)/m );
    return () unless $next;

    return (
        revision       => $revision,
        committer      => $committer,
        committed_date => $committed_date,
    );

}

sub run_cmd {
    my $self = shift;
    return $self->SUPER::run_cmd( "svn", @_ );
}

1;
