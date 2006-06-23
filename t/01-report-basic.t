#!perl -T

use Test::More tests => 5;

BEGIN {
  use_ok( 'Test::Smoke::Report' );
}

use Test::TAP::Model::Visual;

my $m = Test::TAP::Model::Visual->new_with_tests('t/bogus-tests/00-basic.t');

# Test::Harness::Straps breaks under taint mode, so Test::TAP::Model also breaks
my $r = Test::Smoke::Report->new(model => $m, report_text => "foo");
ok($r, "the report object is defined");
isa_ok($r, 'Test::Smoke::Report', "and it's of the correct type");

is($r->model_structure, $m->structure, "the model_structure accessor works");
is($r->report_text, "foo", "the report_text accessor works");
