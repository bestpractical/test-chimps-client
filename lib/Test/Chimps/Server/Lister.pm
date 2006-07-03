package Test::Chimps::Server::Lister;

use warnings;
use strict;

use Params::Validate qw<:all>;
use Test::Chimps::Report;
use HTML::Mason;
use DateTime;
use Date::Parse;

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

sub output_list {
  my ($self, $template_dir, $reports) = @_;

  my $interp = HTML::Mason::Interp->new(comp_root => $template_dir);

  my $categories = $self->_build_heirarchy($reports);

  $interp->exec(File::Spec->catfile(File::Spec->rootdir,
                                    $self->list_template),
                categories => $categories);
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
  return $report->report_variables->{project};
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
  my $res = $b->report_variables->{revision} <=> $a->report_variables->{revision};

  if ($res != 0) {
    return $res;
  }
  
  my ($adate, $bdate) = (DateTime->from_epoch(epoch => str2time($a->report_variables->{timestamp})),
                         DateTime->from_epoch(epoch => str2time($b->report_variables->{timestamp})));
  return DateTime->compare($bdate, $adate);
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
