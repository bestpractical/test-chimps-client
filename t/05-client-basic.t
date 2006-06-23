#!perl -T

use Test::More tests => 6;

use Test::Chimps::Report;
use Test::TAP::Model::Visual;

BEGIN {
  use_ok( 'Test::Chimps::Client' );
}

my $m = Test::TAP::Model::Visual->new_with_tests('t/bogus-tests/00-basic.t');

# Test::Harness::Straps breaks under taint mode, so Test::TAP::Model also breaks
my $r = Test::Chimps::Report->new(model => $m, report_text => "foo");

my $reports = [$r];
my $c = Test::Chimps::Client->new(reports => $reports,
                                  server => 'bogus',
                                  compress => 1);

ok($c, "the client object is defined");
isa_ok($c, 'Test::Chimps::Client', "and it's of the correct type");

is($c->reports, $reports, "the reports accessor works");
is($c->server, "bogus", "the server accessor works");
is($c->compress, 1, "the compress accessor works");
