package Test::Smoke::Report::Client;

use warnings;
use strict;

use Carp;
use Params::Validate qw/:all/;
use Test::Smoke::Report;
use LWP::UserAgent;
use YAML::Syck;

use constant PROTO_VERSION => 0.1;

sub new {
  my $class = shift;
  my $obj = bless {}, $class;
  $obj->_init(@_);
  return $obj;
}

sub _init {
  my $self = shift;
  validate(@_,
           { reports =>
            { type => ARRAYREF },
             server => 1,
             compress => 0});
  
  my %args = @_;
  $self->{reports} = $args{reports};
  foreach my $report (@{$self->{reports}}) {
    croak "one the the specified reports is not a Test::Smoke::Report"
      if ! (ref $report && $report->isa('Test::Smoke::Report'));
  }
  $self->{server} = $args{server};
  $self->{compress} = $args{compress} || 0;
}

sub reports {
  my $self = shift;
  return $self->{reports};
}

sub server {
  my $self = shift;
  return $self->{server};
}

sub compress {
  my $self = shift;
  return $self->{compress};
}

sub send {
  my $self = shift;
  
  my $ua = LWP::UserAgent->new;
  $ua->agent("Test-Smoke-Report-Client/" . PROTO_VERSION);
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

1;
