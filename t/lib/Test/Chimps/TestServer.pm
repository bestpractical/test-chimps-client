package Test::Chimps::TestServer;

use strict;
use warnings;

use base qw(Test::HTTP::Server::Simple HTTP::Server::Simple::CGI Class::Accessor);
__PACKAGE__->mk_accessors(qw(reports_in));

use File::Spec;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use TAP::Harness::Archive;

sub new {
    my $proto = shift;
    my $self = $proto->SUPER::new( @_ );

    $self->reports_in( tempdir(CLEANUP => 1) or die "couldn't create a tmp directory" );

    return $self;
}

sub handle_request {
    my $self = shift;
    my $cgi  = shift;
  
    my $archive = $cgi->upload('archive')
        or die "No archive in the request";

    my $index = ($self->last_report_index||0) + 1;
    my $fname = File::Spec->catfile( $self->reports_in, $index .'.tar.gz');

    open my $fh, '>:raw', $fname or die "Couldn't open file '$fname': $!";
    print $fh do { local $/; <$archive> };
    close $fh;

    print "HTTP/1.1 200 OK\r\n";
    print "Content-Type: text/plain\r\n";
    print "\r\n";
    print "ok\r\n";
}

sub last_report_index {
    my $self = shift;
    my $dir = $self->reports_in;

    opendir my $dh, $dir or die "can't opendir '$dir': $!";
    my ($i) = sort { $b cmp $a } map {/(\d+)/; $1} grep /^\d+\.tar\.gz$/, readdir $dh;
    closedir $dh;

    return $i;
}

sub flush_reports {
    my $self = shift;

    my $dir = $self->reports_in;

    opendir my $dh, $dir or die "can't opendir '$dir': $!";
    my @reports = grep /^\d+\.tar\.gz$/, readdir $dh;
    closedir $dh;

    unlink $_ or die "Couldn't delete file $_"
        foreach map File::Spec->catfile($dir, $_), @reports;
}

sub reports {
    my $self = shift;
    my $index = $self->last_report_index;
    return () unless $index;

    return map $self->report($_), 1 .. $index;
}

sub report {
    my $self = shift;
    my $index = shift;

    my %res;

    my $agg = TAP::Harness::Archive->aggregator_from_archive({
        archive => File::Spec->catfile( $self->reports_in, $index.".tar.gz"),
        parser_callbacks => {},
        meta_yaml_callback => sub {
            $res{'meta'} = $_[0]->[0]
        },
        made_parser_callback => sub {
            my ($parser, $file, $full_path) = @_;
            open my $tap_fh, '<:raw', $full_path
                or die "couldn't open $full_path: $!";
            $res{'TAP'} = do { local $/; <$tap_fh> };
        },
    });
    return \%res;
}

1;
