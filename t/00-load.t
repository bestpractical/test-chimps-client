#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Test::Smoke::Report' );
}

diag( "Testing Test::Smoke::Report $Test::Smoke::Report::VERSION, Perl $], $^X" );
