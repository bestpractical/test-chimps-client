#!perl

use Test::More tests => 6;

BEGIN {
  use_ok( 'Test::Chimps::Client' );
  use_ok( 'Test::TAP::Model::Visual' );
}

my $m = Test::TAP::Model::Visual->new_with_tests('t-data/bogus-tests/00-basic.t');

my $c = Test::Chimps::Client->new(model => $m,
                                  server => 'bogus',
                                  compress => 1);

ok($c, "the client object is defined");
isa_ok($c, 'Test::Chimps::Client', "and it's of the correct type");

is($c->model, $m, "the reports accessor works");
is($c->server, "bogus", "the server accessor works");
is($c->compress, 1, "the compress accessor works");
