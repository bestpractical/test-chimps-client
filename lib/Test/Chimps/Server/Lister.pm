package Test::Chimps::Server::Lister;

use warnings;
use strict;

use Params::Validate qw<:all>;
use Test::Chimps::Report;
use HTML::Mason;
use DateTime;

=head1 NAME

Test::Chimps::Server::Lister - Format the list of smoke reports

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module encapsulates the formatting and output of the smoke
report list.  You should not have to use this module directly
unless you need to customize listing output.  To do so, subclass
C<Lister> and pass one to your C<Server>.

    package MyLister;
    
    use base 'Test::Chimps::Server::Lister';
    
    sub foo { ... }
    
    package main;
    
    use Test::Chimps::Server;
    
    my $lister = MyLister->new();
    
    my $server = Test::Chimps::Server->new(
      base_dir => '/var/www/smokes',
      lister   => $lister
    );
    
    $server->handle_request;

=head1 METHODS

=cut

use base qw/Class::Accessor/;

__PACKAGE__->mk_ro_accessors(
  qw/max_reports_per_subcategory list_template/
);


=head2 new

Returns a new Lister object

=cut

sub new {
  my $class = shift;
  my $obj = bless {}, $class;
  $obj->_init(@_);
  return $obj;
}

sub _init {
  my $self = shift;
  my %args = validate_with(
    params => \@_,
    called => 'The Test::Chimps::Server::Lister constructor',
    spec   => {
      list_template => {
        type     => SCALAR,
        optional => 0,
      },
      max_reports_per_subcategory => {
        type     => SCALAR,
        optional => 0
      }
    }
  );

  foreach my $key (keys %args) {
    $self->{$key} = $args{$key};
  }
}

=head2 output_list

Output the smoke report listing.

=cut

sub output_list {
  my ($self, $template_dir, $reports, $cgi) = @_;

  my $interp = HTML::Mason::Interp->new(comp_root => $template_dir);

  my $categories = $self->_build_heirarchy($reports);

  $interp->exec(File::Spec->catfile(File::Spec->rootdir,
                                    $self->list_template),
                categories => $categories,
                cgi => $cgi);
}

sub _build_heirarchy {
  my $self = shift;
  my $reports = shift;

  my $categories = {};
  foreach my $report (@$reports) {
    my $category = $self->_compute_category($report);
    my $subcategory = $self->_compute_subcategory($report);
    push @{$categories->{$category}->{$subcategory}}, $report;
  }
  $self->_sort_reports($categories);
  $self->_prune_reports($categories);
  return $categories;
}

sub _compute_category {
  my $self = shift;
  my $report = shift;
  return $report->project;
}

sub _compute_subcategory {
  my $self = shift;
  my $report = shift;
  return '';
}

sub _sort_reports {
  my $self = shift;
  my $categories = shift;

  foreach my $category (keys %$categories) {
    foreach my $subcategory (keys %{$categories->{$category}}) {
      @{$categories->{$category}->{$subcategory}} =
        sort _by_revision_then_date @{$categories->{$category}->{$subcategory}};
    }
  }
}

sub _by_revision_then_date {
  my $res = $b->revision <=> $a->revision;

  if ($res != 0) {
    return $res;
  }
  
  return DateTime->compare($b->timestamp, $a->timestamp);
}

sub _prune_reports {
  my $self = shift;
  my $categories = shift;

  foreach my $category (keys %$categories) {
    foreach my $subcategory (keys %{$categories->{$category}}) {
      @{$categories->{$category}->{$subcategory}} =
        @{$categories->{$category}->{$subcategory}}[0 .. ($self->max_reports_per_subcategory - 1)];
    }
  }
}

1;
