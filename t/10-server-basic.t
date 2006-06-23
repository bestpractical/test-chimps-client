#!perl -T

use Test::More tests => 3;

BEGIN {
  use_ok('Test::Chimps::Server');
}

my $s = Test::Chimps::Server->new(base_dir => '/var/www');

ok($s, "the server object is defined");
isa_ok($s, 'Test::Chimps::Server', "and it's of the correct type");
