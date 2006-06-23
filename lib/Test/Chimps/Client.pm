package Test::Chimps::Client;

use warnings;
use strict;

use Carp;
use Params::Validate qw/:all/;
use Test::Chimps;
use LWP::UserAgent;
use YAML::Syck;

use constant PROTO_VERSION => 0.1;

=head1 NAME

Test::Chimps::Client - Send a Test::Chimps::Report to a server

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module simplifies the process of sending
C<Test::Chimps>s to a smoke server.

    use Test::Chimps::Report;
    use Test::Chimps::Client;
    use Test::TAP::Model::Visual;

    chdir "some/module/directory";

    my $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t"));

    my $report = Test::Chimps::Report->new(model => $model);

    my $client = Test::Chimps::Client->new(reports => [$report],
                                           server => 'http://www.example.com/cgi-bin/smoke-server.pl');
    
    my ($status, $msg) = $client->send;
    
    if (! $status) {
      print "Error: $msg\n";
      exit(1);
    }


=head1 METHODS

=head2 new ARGS

Creates a new Client object.  ARGS is a hash whose valid keys are:

=over 4

=item * reports

Mandatory.  The value must be an array reference which contains
C<Test::Chimps>s.  These are the reports that will be
submitted to the server.

=item * server

Mandatory.  The URI of the server script to upload the reports to.

=item * compress

Optional.  Does not currently work

=back

=cut

sub new {
  my $class = shift;
  my $obj = bless {}, $class;
  $obj->_init(@_);
  return $obj;
}

sub _init {
  my $self = shift;
  validate_with(params => \@_,
                spec => 
                { reports =>
                  { type => ARRAYREF },
                  server => 1,
                  compress => 0},
                called => 'The Test::Chimps::Client constructor');
  
  my %args = @_;
  $self->{reports} = $args{reports};
  foreach my $report (@{$self->{reports}}) {
    croak "one the the specified reports is not a Test::Chimps"
      if ! (ref $report && $report->isa('Test::Chimps'));
  }
  $self->{server} = $args{server};
  $self->{compress} = $args{compress} || 0;
}

=head2 reports

Accessor for the reports to be submitted.

=cut

sub reports {
  my $self = shift;
  return $self->{reports};
}

=head2 server

Accessor for the submission server.

=cut

sub server {
  my $self = shift;
  return $self->{server};
}

=head2 compress

Accessor for whether compression is turned on.

=cut

sub compress {
  my $self = shift;
  return $self->{compress};
}

=head2 send

Submit the specified reports to the server.  This function's return
value is a list, the first of which indicates success or failure,
and the second of which is an error string.

=cut

sub send {
  my $self = shift;
  
  my $ua = LWP::UserAgent->new;
  $ua->agent("Test-Chimps-Client/" . PROTO_VERSION);
  $ua->env_proxy;

  my $serialized_reports = [ map { Dump($_) } @{$self->reports} ];
  my %request = (upload => 1, version => PROTO_VERSION,
                 reports => $serialized_reports);

  my $resp = $ua->post($self->server => \%request);
  if($resp->is_success) {
    if($resp->content =~ /^ok/) {
      return (1, '');
    } else {
      return (0, $resp->content);
    }
  } else {
    return (0, $resp->status_line);
  }
}

=head1 AUTHOR

Zev Benjamin, C<< <zev at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-chimps at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Chimps>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Chimps

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Chimps>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Chimps>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Chimps>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Chimps>

=back

=head1 ACKNOWLEDGEMENTS

The code in this distribution is based on smokeserv-client.pl and
smokeserv-server.pl from the PUGS distribution.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Zev Benjamin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

