package Test::Chimps::ReportCollection;

use warnings;
use strict;

=head1 NAME

Test::Chimps::Report - Encapsulate a smoke test report

=head1 SYNOPSIS

FIXME

=head1 METHODS

=head2 new ARGS

Creates a new Report.  ARGS is a hash whose only valid key is
handle.  Its value must be a Jifty::DBI::Handle.

=cut
  
use base qw/Jifty::DBI::Collection/;

=head2 record_class

Overridden method.  Always returns 'Test::Chimps::Report'.

=cut

sub record_class {
  return 'Test::Chimps::Report';
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
smokeserv-server.pl from the Pugs distribution.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Zev Benjamin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
