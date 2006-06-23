package Test::Smoke::Report;

use warnings;
use strict;

use Carp;
use Params::Validate;
use Test::TAP::HTMLMatrix;

=head1 NAME

Test::Smoke::Report - Encapsulate a smoke test report

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module encapsulates a L<Test::TAP::Model>'s structure and a
freeform report text.  If not provided, Test::TAP::HTMLMatrix will
be used to generate the report.

    use Test::Smoke::Report;
    use Test::TAP::Model::Visual;

    chdir "some/module/directory";

    my $model = Test::TAP::Model::Visual->new_with_tests(glob("t/*.t"));

    my $report = Test::Smoke::Report->new(model => $model);

    ...

=head1 METHODS

=head2 new ARGS

Creates a new Report.  ARGS is a hash whose valid keys are C<model>
and C<report_text>.  C<model> is mandatory and must be an instance
of C<Test::Tap::Model>.  C<report_text> is an optional free-form
report.  If not supplied, it is filled in using
C<Test::TAP::HTMLMatrix>.  Note that if you are using this class in
conjunction with C<Test::Smoke::Report::Server>, C<report_text>
should probably be HTML.

=cut

sub new {
  my $class = shift;
  my $obj = bless {}, $class;
  $obj->_init(@_);
  return $obj;
}

sub _init {
  my $self = shift;
  validate(@_,
           { model =>
             { isa => 'Test::TAP::Model'},
             report_text => 0 });

  my %args = @_;

  $self->{model_structure} = $args{model}->structure;
  if (defined $args{report_text}) {
    $self->{report_text} = $args{report_text};
  } else {
    my $v = Test::TAP::HTMLMatrix->new($args{model});
    $self->{report_text} = $v->detail_html;
  }
}

=head2 model_structure

Accessor for the passed-in model's structure.

=cut

sub model_structure {
  my $self = shift;
  return $self->{model_structure};
}

=head2 report_text

Accessor for the report text.

=cut

sub report_text {
  my $self = shift;
  return $self->{report_text};
}

=head1 AUTHOR

Zev Benjamin, C<< <zev at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-smoke-report at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Smoke-Report>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Smoke::Report

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Smoke-Report>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Smoke-Report>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Smoke-Report>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Smoke-Report>

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
