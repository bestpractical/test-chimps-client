#!perl -T

use Test::More tests => 3;

if (-e 't/chimps-home/chimpsdb/database') {
  unlink qw(t/chimps-home/database);
}

BEGIN {
  use_ok('Test::Chimps::Server');
}

my $s = Test::Chimps::Server->new(base_dir => 't/chimps-home');

ok($s, "the server object is defined");
isa_ok($s, 'Test::Chimps::Server', "and it's of the correct type");

unlink qw(t/chimps-home/chimpsdb/database);
