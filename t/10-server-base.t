#!perl -T

use Test::More tests => 3;

BEGIN {
  use_ok('Test::Smoke::Report::Server');
}

my $s = Test::Smoke::Report::Server->new(base_dir => '/var/www');

ok($s, "the server object is defined");
isa_ok($s, 'Test::Smoke::Report::Server', "and it's of the correct type");
