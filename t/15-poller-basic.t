#!perl -T

use Test::More tests => 3;

BEGIN {
  use_ok('Test::Chimps::Client::Poller');
}

my $s = Test::Chimps::Client::Poller->new(server => 'bogus',
                                          config_file => '/home/zev/bps/poll-config.yml');

ok($s, "the server object is defined");
isa_ok($s, 'Test::Chimps::Client::Poller', "and it's of the correct type");
