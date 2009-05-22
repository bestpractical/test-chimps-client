#!perl

use Test::More tests => 5;

BEGIN {
  use_ok( 'Test::Chimps::Client' );
  use_ok( 'Test::TAP::Model::Visual' );
}

use File::Temp;

my $tmp = File::Temp->new;

my $c = Test::Chimps::Client->new(
    archive => $tmp,
    server => 'bogus',
);

ok($c, "the client object is defined");
isa_ok($c, 'Test::Chimps::Client', "and it's of the correct type");
is($c->server, "bogus", "the server accessor works");
